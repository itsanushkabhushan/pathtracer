use bytemuck::{Pod, Zeroable};
use winit::{event::KeyEvent, keyboard::PhysicalKey};

use crate::math::Vec4;

#[derive(Debug, Copy, Clone, Pod, Zeroable)]
#[repr(C)]
pub struct CameraUniforms {
    origin: Vec4,
    u: Vec4,
    v: Vec4,
    w: Vec4,
}

#[derive(Debug, Copy, Clone)]
pub struct Camera {
    uniforms: CameraUniforms, yaw: f32, pitch: f32,
}

impl Camera {
        fn position(&self) -> Vec4 {
        let (sin_phi, cos_phi) = self.yaw.sin_cos();
        let (sin_theta, cos_theta) = self.pitch.sin_cos();
        Vec4::new(
            sin_phi * sin_theta,
            cos_theta,
            cos_phi * sin_theta,
            0.0,
        )
    }
    
    pub fn rotate(&mut self,dx: f32, dy: f32) {
        const MAX_PITCH: f32 = 89.9_f32.to_radians();
        self.yaw += dx;
        self.pitch += dy;
        self.pitch = self.pitch.clamp(-MAX_PITCH, MAX_PITCH);
        let w = self.position().normalized();
        let new_u = w.cross(&Vec4::new(0.0, 1.0, 0.0, 0.0)).normalized();
        let new_v = new_u.cross(&w);
        self.uniforms.u = new_u;
        self.uniforms.v = new_v;   
        self.uniforms.w = w;
    }

    pub fn translate(&mut self, key: KeyEvent) {
        let move_speed = 0.1;

        if key.physical_key == PhysicalKey::Code(winit::keyboard::KeyCode::KeyW) {
            self.uniforms.origin += move_speed * self.uniforms.w;
        }
        if key.physical_key == PhysicalKey::Code(winit::keyboard::KeyCode::KeyS) {
            self.uniforms.origin -= move_speed * self.uniforms.w;
        }
        if key.physical_key == PhysicalKey::Code(winit::keyboard::KeyCode::KeyA) {
            self.uniforms.origin -= move_speed * self.uniforms.u;
        }
        if key.physical_key == PhysicalKey::Code(winit::keyboard::KeyCode::KeyD) {
            self.uniforms.origin += move_speed * self.uniforms.u;
        }
    }
    
    pub fn uniforms(&self) -> &CameraUniforms {
        &self.uniforms 
    }
    pub fn zoom(&mut self, displacement: f32) {
        self.uniforms.origin += displacement * self.uniforms.w;
    }
    pub fn look_at(origin: Vec4, center: Vec4, up: Vec4) -> Camera {
        let w = (center - origin).normalized();
        let u = w.cross(&up).normalized();
        let v = u.cross(&w);
        Camera {
            uniforms: CameraUniforms {
                origin,
                u,
                v,
                w,
            },
            pitch: 0.0,
            yaw: 0.0,
        }
    }

}

  
