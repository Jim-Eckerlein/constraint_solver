use cgmath::{num_traits::Zero, InnerSpace, Quaternion, Rad, Rotation3, Vector3};

use crate::{collision, debug, rigid, solver};

#[derive(Clone, Copy)]
pub struct World {
    a: rigid::Rigid,
    b: rigid::Rigid,
}

impl World {
    pub fn new() -> World {
        let mut a = rigid::Rigid::new(1.0);
        a.external_force.z = -5.0;
        a.velocity.z = -0.2;
        a.angular_velocity.z = 1.0;
        a.frame.position.z = 5.0;
        a.frame.quaternion =
            Quaternion::from_axis_angle(Vector3::new(1.0, 0.5, 0.2).normalize(), Rad(1.0));
        a = a.forget_past();

        let mut b = rigid::Rigid::new(1.0);
        b.frame.position.z = 2.1;
        b = b.forget_past();

        World { a, b }
    }

    pub fn integrate(&mut self, dt: f64, debug_lines: &mut debug::DebugLines) {
        solver::step(&mut self.a, dt, 25);

        const DEBUG_GJK: [f32; 3] = [1.0, 0.0, 1.0];

        for point_a in collision::CUBE_VERTICES {
            let point_a = self.a.frame.act(point_a);
            debug_lines.point(point_a, [0.0, 1.0, 0.0]);

            for point_b in collision::CUBE_VERTICES {
                let point_b = self.b.frame.act(point_b);
            }
        }

        if let Some(collision) = self.a.epa(&self.b) {
            self.a.color = [1.0, 0.0, 0.0];
            self.b.color = [1.0, 0.0, 0.0];
            debug_lines.line(
                vec![Vector3::zero(), collision.depth * collision.normal],
                DEBUG_GJK,
            );
        } else {
            self.a.color = rigid::DEFAULT_COLOR;
            self.b.color = rigid::DEFAULT_COLOR;
        }
    }

    pub fn rigids(&self) -> Vec<&rigid::Rigid> {
        vec![&self.a, &self.b]
    }
}
