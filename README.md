# GPU Path Tracer
 
A real-time GPU path tracer built with **Rust** + **wgpu** and **WGSL** shaders, featuring progressive sample accumulation and an interactive camera.
 
---
 
## Project Structure
 
```
.
├── src/
│   ├── main.rs        # Window, event loop, GPU init, camera input
│   ├── render.rs      # PathTracer renderer (pipeline, bind groups, frame logic)
│   ├── camera.rs      # Camera: look-at, rotation, zoom, translation
│   ├── math.rs        # Vec4 and math utilities
│   └── shaders.wgsl   # WGSL path tracing shader
```
 
---
 
## Features
 
- Progressive path tracing with per-frame sample accumulation
- Three materials: **Lambertian** (diffuse), **Metal** (specular), **Glass** (refraction + TIR)
- Sub-pixel jitter antialiasing via xorshift PRNG
- Interactive camera — mouse look, WASD translation, scroll-to-zoom
- Sky gradient background
---
 
## Scene
 
Four spheres: a glass bubble, a large diffuse ground plane, a mirror sphere, and a lavender diffuse sphere.
 
---
 
## Building & Running
 
### Prerequisites
- [Rust](https://rustup.rs/) (stable)
- A GPU with Vulkan/Metal/DX12 support
```bash
cargo run --release
```
 
Opens an 800×600 window. Quality improves the longer the camera stays still — any movement resets accumulated samples.
 
---
 
## Controls
 
| Input | Action |
|---|---|
| `W` / `S` | Move forward / backward |
| `A` / `D` | Strafe left / right |
| Mouse move | Look around |
| Scroll wheel | Zoom |

## Author
Anushka Bhushan
