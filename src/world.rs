use cgmath::{vec3, Deg, Quaternion, Rotation3};

use crate::{debug, geometry::Plane, rigid, solver};

#[derive(Clone, Copy)]
pub struct World {
    a: rigid::Rigid,
    b: rigid::Rigid,
}

impl World {
    pub fn new() -> World {
        let mut a = rigid::Rigid::new(1.0);
        a.frame.position.z = 2.0;
        a.frame.position.y = -1.1;
        a.frame.quaternion =
            Quaternion::from_angle_x(Deg(45.0)) * Quaternion::from_angle_y(Deg(45.0));

        let mut b = rigid::Rigid::new(1.0);
        b.frame.position.z = 1.0;

        World { a, b }
    }

    pub fn integrate(&mut self, dt: f64, debug: &mut debug::DebugLines) {
        // solver::step(&mut self.a, dt, 25);

        // let test = self.a.sat(&self.b, debug);

        // if test {
        //     self.a.color = Some([1.0, 0.0, 0.0]);
        //     self.b.color = Some([1.0, 0.0, 0.0]);
        // } else {
        //     self.a.color = None;
        //     self.b.color = None;
        // }

        debug.plane(
            Plane::from_points([
                vec3(1.0, 0.0, 0.0),
                vec3(0.0, 1.0, 0.0),
                vec3(0.0, 0.0, 1.0),
            ]),
            [0.0, 1.0, 1.0],
        );
    }

    pub fn rigids(&self) -> Vec<&rigid::Rigid> {
        vec![&self.a, &self.b]
    }
}
