---
title: BlumeOps
date-modified: 2026-02-08
aliases: []
id: index
tags: []
---

Welcome to the BlumeOps (aka "Blue Mops") documentation. Here you will find
hopefully everything you'll need to understand and operate my personal digital
infrastructure.

**New here?** Start with [[exploring-the-docs]] to find your way around.

## What is BlumeOps?

BlumeOps is my personal homelab infrastructure managed entirely through code.
Everything lives in a [single git repository](https://github.com/eblume/blumeops), from service configs to
deployment automation. Even the [[forgejo]] instance that [hosts this repo](https://forge.ops.eblu.me/eblume/blumeops)
is defined within it, making BlumeOps fully self-hosting. It's a digital life
raft I built for myself as I went, and you can see it all from within your
editor of choice. (I recommend vim.)

These services run on my home [[hosts|infrastructure]], primarily an m1 mac
mini named [[indri]] and a Synology NAS called [[sifaka]]. The infrastructure
is networked via [[tailscale]], with the domain `eblu.me` hosted via [[gandi]],
[[caddy]] providing a private reverse proxy for tailnet devices, and
[[flyio-proxy|Fly.io]] serving public-facing services like
[this documentation site](https://docs.eblu.me).

The goal of BlumeOps is threefold:

1. To provide a rich array of useful personal services in order to manage my
   own digital life.
2. To exercise my skills as a software engineer specializing in
   Platforms/DevOps/SRE.
3. To act as a portfolio piece for talking about building hosted software
   platforms.

## Sections

- [[tutorials|Tutorials]] - Learning-oriented guides for getting started
- [[reference|Reference]] - Technical specifications and service details
- [[how-to|How-to]] - Task-oriented instructions for common operations
- [[explanation|Explanation]] - Understanding the "why" behind BlumeOps
- [[CHANGELOG]] - Release history and changes
