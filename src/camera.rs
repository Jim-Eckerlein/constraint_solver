use cgmath::Matrix4;
use geometric_algebra::{
    pga3::{Dir, Rotor, Translator},
    Reversal,
};
use std::f64::consts::TAU;

use crate::numeric::{motor_to_matrix, Y_UP, Z_UP};

pub struct Camera {
    pub orbit: f64,
    pub tilt: f64,
    pub distance: f64,
    pub fovy: f64,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct CameraUniforms {
    pub view: Matrix4<f32>,
    pub view_inverse: Matrix4<f32>,
    pub proj: Matrix4<f32>,
}

unsafe impl bytemuck::Pod for CameraUniforms {}
unsafe impl bytemuck::Zeroable for CameraUniforms {}

impl Camera {
    pub fn initial() -> Self {
        Self {
            orbit: 1.0,
            tilt: 0.2 * 0.25 * TAU,
            distance: 12.0,
            fovy: 60.0,
        }
    }

    pub fn clamp_tilt(&mut self) {
        self.tilt = self.tilt.clamp(-TAU / 4.0, TAU / 4.0);
    }

    pub fn uniforms(&self, aspect: f64) -> CameraUniforms {
        let orbit = Rotor::from_angle_axis(self.orbit as f32, Dir::new(0.0, -1.0, 0.0));
        let tilt = Rotor::from_angle_axis(self.tilt as f32, Dir::new(-1.0, 0.0, 0.0));
        let translation = Translator::new(0.0, 0.0, -1.0 * self.distance as f32);

        let view_motor = translation * tilt * orbit;
        let view = motor_to_matrix(view_motor) * Y_UP;
        let view_inverse = Z_UP * motor_to_matrix(view_motor.reversal());

        let proj = perspective_matrix(60.0_f64.to_radians(), aspect, 0.01, None);

        CameraUniforms {
            view,
            view_inverse,
            proj,
        }
    }
}

fn perspective_matrix(fovy: f64, aspect: f64, near: f64, far: Option<f64>) -> Matrix4<f32> {
    let tan_half_fovy = (0.5 * fovy).tan();
    if let Some(far) = far {
        [
            [(1.0 / (aspect * tan_half_fovy)) as f32, 0.0, 0.0, 0.0],
            [0.0, (1.0 / (tan_half_fovy)) as f32, 0.0, 0.0],
            [0.0, 0.0, (-(far + near) / (far - near)) as f32, -1.0],
            [0.0, 0.0, (-(2.0 * far * near) / (far - near)) as f32, 0.0],
        ]
    } else {
        [
            [(1.0 / (aspect * tan_half_fovy)) as f32, 0.0, 0.0, 0.0],
            [0.0, (1.0 / (tan_half_fovy)) as f32, 0.0, 0.0],
            [0.0, 0.0, -1.0, -1.0],
            [0.0, 0.0, (-2.0 * near) as f32, 0.0],
        ]
    }
    .into()
}
