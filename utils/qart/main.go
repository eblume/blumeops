// QArt Tuner — generates QR codes whose data modules form a recognizable image.
//
// This tool implements the QArt technique described by Russ Cox at
// https://research.swtch.com/qart. The technique exploits QR error correction:
// by choosing data/check bit values that satisfy the Reed-Solomon constraints
// while also matching a target image's brightness, the QR modules themselves
// draw a picture.
//
// This implementation uses the rsc.io/qr library for QR layout, encoding, and
// GF(256) arithmetic. The image-targeting algorithm (bit selection via GF(2)
// Gaussian elimination, contrast-priority ordering, and image preprocessing)
// is an original implementation based on the technique description.
//
// Written by Claude Code (Opus 4.6) with direction from Erich Blume.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"sort"
	"strconv"
	"time"

	"rsc.io/qr"
	"rsc.io/qr/coding"
	"rsc.io/qr/gf256"
)

// ---------------------------------------------------------------------------
// CLI & web server
// ---------------------------------------------------------------------------

func main() {
	var (
		url      = flag.String("url", "", "URL to encode")
		imgPath  = flag.String("image", "", "path to source image")
		outPath  = flag.String("out", "qart.png", "output PNG path")
		version  = flag.Int("version", 6, "QR version (1-8)")
		mask     = flag.Int("mask", 0, "QR mask pattern (0-7)")
		scale    = flag.Int("scale", 8, "pixel scale factor")
		dither   = flag.Bool("dither", false, "use dithering")
		rotation = flag.Int("rotation", 0, "rotation (0-3, quarter turns)")
		dx       = flag.Int("dx", 0, "image X offset (positive = shift right)")
		dy       = flag.Int("dy", 0, "image Y offset (positive = shift down)")
		seed     = flag.Int64("seed", 0, "random seed (0 = use time)")
		allMasks = flag.Bool("all-masks", false, "generate all 8 mask variants")
		serve    = flag.Bool("serve", false, "start web UI for interactive tuning")
		port     = flag.Int("port", 8088, "port for web UI")
	)
	flag.Parse()

	if *url == "" || *imgPath == "" {
		fmt.Fprintf(os.Stderr, "usage: qart-gen -url URL -image IMAGE [-out OUTPUT] [-serve]\n")
		os.Exit(1)
	}

	imgData, err := os.ReadFile(*imgPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "reading image: %v\n", err)
		os.Exit(1)
	}

	if *serve {
		startServer(imgData, *url, *port)
		return
	}

	pickSeed := func() int64 {
		if *seed != 0 {
			return *seed
		}
		return time.Now().UnixNano()
	}

	if *allMasks {
		for m := 0; m < 8; m++ {
			out := fmt.Sprintf("%s_mask%d.png", (*outPath)[:len(*outPath)-4], m)
			pngBytes, err := renderQArt(imgData, *url, *version, m, *scale, *rotation, *dx, *dy, *dither, pickSeed())
			if err != nil {
				fmt.Fprintf(os.Stderr, "mask %d: %v\n", m, err)
				continue
			}
			os.WriteFile(out, pngBytes, 0644)
			fmt.Printf("wrote %s\n", out)
		}
	} else {
		pngBytes, err := renderQArt(imgData, *url, *version, *mask, *scale, *rotation, *dx, *dy, *dither, pickSeed())
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}
		os.WriteFile(*outPath, pngBytes, 0644)
		fmt.Printf("wrote %s\n", *outPath)
	}
}

func intParam(r *http.Request, name string, def int) int {
	v := r.URL.Query().Get(name)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}

func startServer(imgData []byte, url string, port int) {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte(indexHTML))
	})

	renderHandler := func(w http.ResponseWriter, r *http.Request, download bool) {
		version := intParam(r, "version", 6)
		mask := intParam(r, "mask", 0)
		scale := intParam(r, "scale", 8)
		rotation := intParam(r, "rotation", 0)
		dx := intParam(r, "dx", 0)
		dy := intParam(r, "dy", 0)
		dither := r.URL.Query().Get("dither") == "1"
		seed := int64(intParam(r, "seed", 0))
		if seed == 0 {
			seed = time.Now().UnixNano()
		}

		pngData, err := renderQArt(imgData, url, version, mask, scale, rotation, dx, dy, dither, seed)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		w.Header().Set("Content-Type", "image/png")
		if download {
			w.Header().Set("Content-Disposition",
				fmt.Sprintf("attachment; filename=qart_v%d_m%d_dx%d_dy%d.png", version, mask, dx, dy))
		} else {
			w.Header().Set("Cache-Control", "no-cache")
		}
		w.Write(pngData)
	}

	http.HandleFunc("/generate", func(w http.ResponseWriter, r *http.Request) {
		renderHandler(w, r, false)
	})
	http.HandleFunc("/save", func(w http.ResponseWriter, r *http.Request) {
		renderHandler(w, r, true)
	})

	addr := fmt.Sprintf("localhost:%d", port)
	fmt.Printf("QArt tuner running at http://%s\n", addr)
	if runtime.GOOS == "darwin" {
		exec.Command("open", "http://"+addr).Start()
	}
	if err := http.ListenAndServe(addr, nil); err != nil {
		fmt.Fprintf(os.Stderr, "server error: %v\n", err)
		os.Exit(1)
	}
}

// ---------------------------------------------------------------------------
// QArt rendering — original implementation of the technique from
// https://research.swtch.com/qart using only the public rsc.io/qr API.
// ---------------------------------------------------------------------------

// renderQArt produces a PNG of a QR code encoding url whose data modules
// approximate the brightness pattern of the source image.
func renderQArt(imgData []byte, url string, version, mask, scale, rotation, dx, dy int, dither bool, seed int64) ([]byte, error) {
	if version > 8 {
		version = 8
	}
	if scale < 1 {
		scale = 8
	}

	// Build the QR plan — this tells us where every pixel goes and its role.
	plan, err := coding.NewPlan(coding.Version(version), coding.L, coding.Mask(mask))
	if err != nil {
		return nil, err
	}

	rotatePixels(plan, rotation)

	// Build the grayscale target image scaled to QR module grid size.
	gridSize := 17 + 4*version
	target, err := imageToTarget(imgData, gridSize)
	if err != nil {
		return nil, err
	}

	// Encode the URL into QR data, filling remaining capacity with numeric
	// padding that we can freely manipulate.
	urlStr := url + "#"
	var bits coding.Bits
	coding.String(urlStr).Encode(&bits, plan.Version)
	coding.Num("").Encode(&bits, plan.Version)
	fixedBits := bits.Bits()
	freeBits := plan.DataBytes*8 - fixedBits
	if freeBits < 0 {
		return nil, fmt.Errorf("URL too long for QR version %d", version)
	}

	// Fill free space with numeric '0's — 10 bits per 3 digits.
	numDigits := freeBits / 10 * 3
	num := make([]byte, numDigits)
	for i := range num {
		num[i] = '0'
	}

	rng := rand.New(rand.NewSource(seed))

	// Iterate: encode, manipulate bits to match image, extract numeric
	// digits back out, re-encode. Loop if any 10-bit group >= 1000.
	type pixInfo struct {
		x, y     int
		pix      coding.Pixel
		targ     byte // target brightness (0=black, 255=white)
		contrast int  // local contrast (variance); higher = more visually important
		hardZero bool
	}

	var hardZeros map[int]bool

	for attempt := 0; attempt < 10; attempt++ {
		bits.Pad(freeBits)
		bits.Reset()
		coding.String(urlStr).Encode(&bits, plan.Version)
		coding.Num(coding.Num(num)).Encode(&bits, plan.Version)
		bits.AddCheckBytes(plan.Version, plan.Level)
		data := bits.Bytes()

		// Index every data/check pixel by its bit offset in the codeword stream.
		totalBits := (plan.DataBytes + plan.CheckBytes) * 8
		pixByOff := make([]pixInfo, totalBits)
		for y, row := range plan.Pixel {
			for x, pix := range row {
				role := pix.Role()
				if role != coding.Data && role != coding.Check {
					continue
				}
				t, c := targetAt(target, x+dx, y+dy)
				if c >= 0 {
					c = c<<8 | rng.Intn(256)
				}
				pi := pixInfo{x: x, y: y, pix: pix, targ: t, contrast: c}
				if hardZeros[int(pix.Offset())] {
					pi.hardZero = true
					pi.contrast = 1<<30 | rng.Intn(256)
				}
				pixByOff[pix.Offset()] = pi
			}
		}

		// Process each ECC block independently.
		ndBase := plan.DataBytes / plan.Blocks
		nc := plan.CheckBytes / plan.Blocks
		extra := plan.DataBytes - ndBase*plan.Blocks
		rs := gf256.NewRSEncoder(coding.Field, nc)
		usableBits := fixedBits + freeBits/10*10

		doff, coff := 0, 0
		for block := 0; block < plan.Blocks; block++ {
			nd := ndBase
			if block >= plan.Blocks-extra {
				nd++
			}
			bdata := data[doff/8 : doff/8+nd]
			cdata := data[plan.DataBytes+coff/8 : plan.DataBytes+coff/8+nc]

			bb := newBitBlock(nd, nc, rs, bdata, cdata)

			// Determine the editable bit range within this block's data bytes.
			lo, hi := 0, nd*8
			if fixedBits-doff > lo {
				lo = fixedBits - doff
			}
			if lo > hi {
				lo = hi
			}
			if usableBits-doff < hi {
				hi = usableBits - doff
			}
			if hi < lo {
				hi = lo
			}

			// Lock the preserved bits.
			for i := 0; i < lo; i++ {
				bb.fix(uint(i), (bdata[i/8]>>uint(7-i&7))&1)
			}
			for i := hi; i < nd*8; i++ {
				bb.fix(uint(i), (bdata[i/8]>>uint(7-i&7))&1)
			}

			// Collect editable bits, sorted by visual importance.
			type candidate struct {
				globalOff int
				priority  int
			}
			candidates := make([]candidate, 0, (hi-lo)+nc*8)
			for i := lo; i < hi; i++ {
				candidates = append(candidates, candidate{doff + i, pixByOff[doff+i].contrast})
			}
			for i := 0; i < nc*8; i++ {
				candidates = append(candidates, candidate{plan.DataBytes*8 + coff + i, pixByOff[plan.DataBytes*8+coff+i].contrast})
			}
			sort.Slice(candidates, func(i, j int) bool {
				return candidates[i].priority > candidates[j].priority
			})

			// Try to set each bit to match target brightness.
			for _, cand := range candidates {
				pi := &pixByOff[cand.globalOff]
				desired := byte(1) // dark target → black pixel
				if pi.targ >= 128 {
					desired = 0
				}
				if pi.pix&coding.Invert != 0 {
					desired ^= 1
				}
				if pi.hardZero {
					desired = 0
				}

				var localBit int
				if pi.pix.Role() == coding.Data {
					localBit = cand.globalOff - doff
				} else {
					localBit = cand.globalOff - plan.DataBytes*8 - coff + nd*8
				}
				bb.trySet(uint(localBit), desired)
			}

			bb.writeback()
			doff += nd * 8
			coff += nc * 8
		}

		// Extract numeric digits back from the modified data stream.
		overflow := false
		for i := 0; i < freeBits/10; i++ {
			v := 0
			for j := 0; j < 10; j++ {
				bi := uint(fixedBits + 10*i + j)
				v = v<<1 | int((data[bi/8]>>(7-bi&7))&1)
			}
			if v >= 1000 {
				if hardZeros == nil {
					hardZeros = make(map[int]bool)
				}
				hardZeros[fixedBits+10*i+3] = true
				overflow = true
			}
			num[i*3+0] = byte(v/100 + '0')
			num[i*3+1] = byte(v/10%10 + '0')
			num[i*3+2] = byte(v%10 + '0')
		}
		if overflow {
			continue
		}

		// Final encode with the settled numeric digits.
		code, err := plan.Encode(coding.String(urlStr), coding.Num(coding.Num(num)))
		if err != nil {
			return nil, err
		}

		qrCode := &qr.Code{Bitmap: code.Bitmap, Size: code.Size, Stride: code.Stride, Scale: scale}
		return qrCode.PNG(), nil
	}

	return nil, fmt.Errorf("could not settle numeric encoding after retries")
}

// ---------------------------------------------------------------------------
// BitBlock — GF(2) linear system for choosing ECC-consistent bit values.
//
// A QR ECC block has nd data bytes and nc check bytes related by Reed-Solomon
// coding. Flipping a data bit deterministically changes certain check bits.
// We model this as a matrix over GF(2): each data bit has a row showing which
// bytes change when it's toggled. Gaussian elimination lets us find a set of
// independent bits we can freely assign while keeping the block valid.
// ---------------------------------------------------------------------------

type bitBlock struct {
	nd, nc int
	buf    []byte   // current data+check bytes (nd+nc)
	rows   [][]byte // unconsumed basis rows (Gaussian elimination workspace)
	used   [][]byte // rows that have been consumed (for reset)
	rs     *gf256.RSEncoder
	bdata  []byte // slice into the original data array
	cdata  []byte // slice into the original check array
}

func newBitBlock(nd, nc int, rs *gf256.RSEncoder, bdata, cdata []byte) *bitBlock {
	bb := &bitBlock{
		nd:    nd,
		nc:    nc,
		buf:   make([]byte, nd+nc),
		rows:  make([][]byte, 0, nd*8),
		rs:    rs,
		bdata: bdata,
		cdata: cdata,
	}

	// Initialize buf with current data and compute its check bytes.
	copy(bb.buf, bdata)
	rs.ECC(bb.buf[:nd], bb.buf[nd:])

	// Build the basis matrix: for each data bit, compute the effect of
	// toggling that bit on the full data+check byte vector.
	for i := 0; i < nd*8; i++ {
		row := make([]byte, nd+nc)
		row[i/8] = 1 << (7 - uint(i%8))
		rs.ECC(row[:nd], row[nd:])
		bb.rows = append(bb.rows, row)
	}

	return bb
}

// fix locks a data bit to a specific value, consuming one degree of freedom.
func (bb *bitBlock) fix(bit uint, val byte) {
	bb.trySet(bit, val)
}

// trySet attempts to set a bit to val using Gaussian elimination.
// Finds a row with a 1 in the target column, eliminates that column from all
// other rows, then applies the row to buf if needed.
func (bb *bitBlock) trySet(bit uint, val byte) bool {
	byteIdx, bitMask := bit/8, byte(1<<(7-bit&7))

	// Find a row with a 1 in this column.
	found := -1
	for i, row := range bb.rows {
		if row[byteIdx]&bitMask != 0 {
			found = i
			break
		}
	}
	if found < 0 {
		return (bb.buf[byteIdx]>>(7-bit&7))&1 == val
	}

	// Move pivot to front.
	bb.rows[0], bb.rows[found] = bb.rows[found], bb.rows[0]
	pivot := bb.rows[0]

	// Eliminate this column from all other rows.
	for _, row := range bb.rows[1:] {
		if row[byteIdx]&bitMask != 0 {
			xorBytes(row, pivot)
		}
	}
	for _, row := range bb.used {
		if row[byteIdx]&bitMask != 0 {
			xorBytes(row, pivot)
		}
	}

	// Apply if needed.
	if (bb.buf[byteIdx]>>(7-bit&7))&1 != val {
		xorBytes(bb.buf, pivot)
	}

	// Consume the pivot.
	bb.used = append(bb.used, pivot)
	bb.rows = bb.rows[1:]
	return true
}

// writeback copies solved bytes back to the original arrays.
func (bb *bitBlock) writeback() {
	copy(bb.bdata, bb.buf[:bb.nd])
	copy(bb.cdata, bb.buf[bb.nd:])
}

func xorBytes(dst, src []byte) {
	for i := range dst {
		dst[i] ^= src[i]
	}
}

// ---------------------------------------------------------------------------
// Image processing
// ---------------------------------------------------------------------------

// imageToTarget decodes an image and converts it to a grayscale grid at the
// given resolution, returning brightness values (0-255, -1 for transparent).
func imageToTarget(data []byte, size int) ([][]int, error) {
	src, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}

	b := src.Bounds()
	tw, th := size, size
	if b.Dx() > b.Dy() {
		th = b.Dy() * tw / b.Dx()
	} else {
		tw = b.Dx() * th / b.Dy()
	}

	grid := make([][]int, size)
	for y := range grid {
		row := make([]int, size)
		for x := range row {
			row[x] = -1
		}
		grid[y] = row
	}

	for y := 0; y < th; y++ {
		for x := 0; x < tw; x++ {
			sx := b.Min.X + x*b.Dx()/tw
			sy := b.Min.Y + y*b.Dy()/th
			r, g, bl, a := src.At(sx, sy).RGBA()
			if a == 0 {
				continue
			}
			lum := (299*uint32(r>>8) + 587*uint32(g>>8) + 114*uint32(bl>>8) + 500) / 1000
			grid[y][x] = int(lum)
		}
	}
	return grid, nil
}

// targetAt returns brightness and local contrast for a pixel.
func targetAt(target [][]int, x, y int) (brightness byte, contrast int) {
	if y < 0 || y >= len(target) || x < 0 || x >= len(target[y]) {
		return 255, -1
	}
	v := target[y][x]
	if v < 0 {
		return 255, -1
	}

	n, sum, sumsq := 0, 0, 0
	const radius = 5
	for dy := -radius; dy <= radius; dy++ {
		for dx := -radius; dx <= radius; dx++ {
			ny, nx := y+dy, x+dx
			if ny >= 0 && ny < len(target) && nx >= 0 && nx < len(target[ny]) && target[ny][nx] >= 0 {
				val := target[ny][nx]
				sum += val
				sumsq += val * val
				n++
			}
		}
	}
	if n == 0 {
		return byte(v), 0
	}
	avg := sum / n
	return byte(v), sumsq/n - avg*avg
}

// rotatePixels rotates the QR plan's pixel grid by rot quarter turns.
func rotatePixels(plan *coding.Plan, rot int) {
	rot = rot % 4
	if rot == 0 {
		return
	}
	n := len(plan.Pixel)
	dst := make([][]coding.Pixel, n)
	for i := range dst {
		dst[i] = make([]coding.Pixel, n)
	}
	for y := 0; y < n; y++ {
		for x := 0; x < n; x++ {
			switch rot {
			case 1:
				dst[y][x] = plan.Pixel[x][n-1-y]
			case 2:
				dst[y][x] = plan.Pixel[n-1-y][n-1-x]
			case 3:
				dst[y][x] = plan.Pixel[n-1-x][y]
			}
		}
	}
	plan.Pixel = dst
}

// ---------------------------------------------------------------------------
// Embedded web UI
// ---------------------------------------------------------------------------

const indexHTML = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>QArt Tuner</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: system-ui, -apple-system, sans-serif; background: #1a1a2e; color: #e0e0e0; display: flex; height: 100vh; }
  #controls { width: 320px; padding: 20px; overflow-y: auto; background: #16213e; border-right: 1px solid #0f3460; }
  #preview { flex: 1; display: flex; align-items: center; justify-content: center; flex-direction: column; gap: 16px; }
  #preview img { image-rendering: pixelated; max-width: 90%; max-height: 80vh; background: white; }
  h1 { font-size: 18px; margin-bottom: 16px; color: #e94560; }
  .control { margin-bottom: 14px; }
  .control label { display: flex; justify-content: space-between; font-size: 13px; margin-bottom: 4px; color: #a0a0c0; }
  .control label span { color: #e94560; font-weight: bold; font-variant-numeric: tabular-nums; }
  input[type="range"] { width: 100%; accent-color: #e94560; }
  .checkbox-row { display: flex; align-items: center; gap: 8px; margin-bottom: 14px; }
  .checkbox-row input { accent-color: #e94560; }
  .checkbox-row label { font-size: 13px; color: #a0a0c0; }
  button { width: 100%; padding: 10px; margin-top: 8px; border: none; border-radius: 6px; cursor: pointer; font-size: 14px; font-weight: bold; }
  #saveBtn { background: #e94560; color: white; }
  #saveBtn:hover { background: #c73e55; }
  #randomBtn { background: #0f3460; color: #e0e0e0; border: 1px solid #e94560; }
  #randomBtn:hover { background: #1a4a80; }
  #status { font-size: 12px; color: #666; margin-top: 12px; text-align: center; }
  .params { font-size: 11px; color: #606080; background: #0f3460; padding: 8px; border-radius: 4px; margin-top: 12px; font-family: monospace; word-break: break-all; }
</style>
</head>
<body>
<div id="controls">
  <h1>QArt Tuner</h1>
  <div class="control">
    <label>Version <span id="versionVal">6</span></label>
    <input type="range" id="version" min="1" max="8" value="6">
  </div>
  <div class="control">
    <label>Mask <span id="maskVal">0</span></label>
    <input type="range" id="mask" min="0" max="7" value="0">
  </div>
  <div class="control">
    <label>Rotation <span id="rotationVal">0</span></label>
    <input type="range" id="rotation" min="0" max="3" value="0">
  </div>
  <div class="control">
    <label>DX (horizontal) <span id="dxVal">0</span></label>
    <input type="range" id="dx" min="-15" max="15" value="0">
  </div>
  <div class="control">
    <label>DY (vertical) <span id="dyVal">0</span></label>
    <input type="range" id="dy" min="-15" max="15" value="0">
  </div>
  <div class="control">
    <label>Scale <span id="scaleVal">8</span></label>
    <input type="range" id="scale" min="1" max="16" value="8">
  </div>
  <div class="checkbox-row">
    <input type="checkbox" id="dither">
    <label for="dither">Dither</label>
  </div>
  <button id="randomBtn">Random seed</button>
  <button id="saveBtn">Save PNG</button>
  <div class="params" id="params"></div>
  <div id="status"></div>
</div>
<div id="preview">
  <img id="qrimg" src="" alt="QArt code">
</div>
<script>
const controls = ['version', 'mask', 'rotation', 'dx', 'dy', 'scale'];
const checkboxes = ['dither'];
let seed = 0;
let pending = false;
let needsUpdate = false;

function getParams() {
  const p = new URLSearchParams();
  controls.forEach(name => {
    p.set(name, document.getElementById(name).value);
  });
  checkboxes.forEach(name => {
    p.set(name, document.getElementById(name).checked ? '1' : '0');
  });
  if (seed) p.set('seed', seed);
  return p;
}

function updateDisplay() {
  controls.forEach(name => {
    const el = document.getElementById(name);
    document.getElementById(name + 'Val').textContent = el.value;
  });
  const p = getParams();
  document.getElementById('params').textContent =` + " `-version ${p.get('version')} -mask ${p.get('mask')} -rotation ${p.get('rotation')} -dx ${p.get('dx')} -dy ${p.get('dy')} -scale ${p.get('scale')}${p.get('dither') === '1' ? ' -dither' : ''}`" + `;
}

function refresh() {
  if (pending) { needsUpdate = true; return; }
  pending = true;
  updateDisplay();
  const params = getParams();
  const start = performance.now();
  document.getElementById('status').textContent = 'generating...';
  fetch('/generate?' + params.toString())
    .then(r => {
      if (!r.ok) return r.text().then(t => { throw new Error(t); });
      return r.blob();
    })
    .then(blob => {
      const objectUrl = URL.createObjectURL(blob);
      const img = document.getElementById('qrimg');
      img.onload = () => URL.revokeObjectURL(objectUrl);
      img.src = objectUrl;
      document.getElementById('status').textContent = Math.round(performance.now() - start) + 'ms';
    })
    .catch(err => {
      document.getElementById('status').textContent = 'Error: ' + err.message;
    })
    .finally(() => {
      pending = false;
      if (needsUpdate) { needsUpdate = false; refresh(); }
    });
}

controls.forEach(name => {
  document.getElementById(name).addEventListener('input', refresh);
});
checkboxes.forEach(name => {
  document.getElementById(name).addEventListener('change', refresh);
});
document.getElementById('randomBtn').addEventListener('click', () => {
  seed = Math.floor(Math.random() * 2147483647);
  refresh();
});
document.getElementById('saveBtn').addEventListener('click', () => {
  window.location.href = '/save?' + getParams().toString();
});
document.addEventListener('keydown', (e) => {
  if (e.target.tagName === 'INPUT' && e.target.type !== 'checkbox') return;
  const map = {
    'ArrowLeft': ['dx', -1], 'ArrowRight': ['dx', 1],
    'ArrowUp': ['dy', -1], 'ArrowDown': ['dy', 1],
    '[': ['mask', -1], ']': ['mask', 1],
    '-': ['version', -1], '=': ['version', 1],
    'r': ['rotation', 1],
  };
  const action = map[e.key];
  if (!action) return;
  e.preventDefault();
  const el = document.getElementById(action[0]);
  el.value = Math.max(parseInt(el.min), Math.min(parseInt(el.max), parseInt(el.value) + action[1]));
  refresh();
});
refresh();
</script>
</body>
</html>`
