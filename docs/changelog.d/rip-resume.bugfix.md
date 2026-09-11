`rip-cd` resumes an interrupted extraction from the first missing track
instead of re-ripping the whole disc: complete WAVs (size matches the
track's sector count) are kept, the partial one a killed cd-paranoia was
writing is discarded, and only the missing span is extracted. Found when a
`makemkvcon info` probe contended for the drive mid-rip and wedged
cd-paranoia in an uninterruptible read. See [[rip-a-disc]].
Ejecting now force-unmounts the cddafs volume first, since `drutil eject`
is refused while Finder or loginwindow holds it.
