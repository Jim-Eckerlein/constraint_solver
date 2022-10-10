mod epa;
mod gjk;
mod sat;

use std::cell::RefCell;

use cgmath::{vec3, InnerSpace, Vector3, Zero};
use itertools::Itertools;

use crate::{
    constraint::Constraint,
    debug,
    geometry::{self, Plane},
    rigid::Rigid,
};

pub fn ground<'a>(
    rigid: &'a RefCell<&'a mut Rigid>,
    polytope: &geometry::Polytope,
) -> Vec<Constraint<'a>> {
    let mut constraints = Vec::new();

    for &vertex in &polytope.vertices {
        let position = rigid.borrow().frame.act(vertex);
        if position.z >= 0.0 {
            continue;
        }

        let target_position = Vector3::new(position.x, position.y, 0.0);
        let correction = target_position - position;
        let delta_position = rigid.borrow().delta(position);
        let delta_tangential_position = delta_position - delta_position.project_on(correction);

        constraints.push(Constraint {
            rigid,
            contacts: (position, target_position - 1.0 * delta_tangential_position),
            distance: 0.0,
        })
    }

    constraints
}

impl Rigid {
    fn support(&self, polytope: &geometry::Polytope, dir: Vector3<f64>) -> Vector3<f64> {
        polytope
            .vertices
            .iter()
            .copied()
            .map(|p| self.frame.act(p))
            .max_by(|a, b| a.dot(dir).total_cmp(&b.dot(dir)))
            .unwrap()
    }

    fn minkowski_support(
        &self,
        other: &Rigid,
        polytope: &geometry::Polytope,
        direction: Vector3<f64>,
    ) -> Vector3<f64> {
        self.support(polytope, direction) - other.support(polytope, -direction)
    }

    #[allow(dead_code)]
    pub fn gjk(&self, other: &Rigid, polytope: &geometry::Polytope) -> Option<gjk::Tetrahedron> {
        let mut direction = -self.minkowski_support(other, polytope, Vector3::unit_x());
        let mut simplex = gjk::Simplex::Point(-direction);

        loop {
            let support = self.minkowski_support(other, polytope, direction);

            if direction.dot(support) <= 0.0 {
                return None;
            }

            match simplex.enclose(support) {
                Ok(simplex) => return Some(simplex),
                Err((next_simplex, next_direction)) => {
                    simplex = next_simplex;
                    direction = next_direction;
                }
            };
        }
    }

    #[allow(dead_code)]
    pub fn epa(&self, other: &Rigid, polytope: &geometry::Polytope) -> Option<epa::Collision> {
        let simplex = self.gjk(other, polytope)?;

        let mut expanding_polytope = epa::Polytope::new(simplex);

        loop {
            let minimal_face = Plane::from_points(
                expanding_polytope.face_vertices(expanding_polytope.minimal_face()),
            );
            let support = self.minkowski_support(other, polytope, minimal_face.normal);

            if polytope.vertices.contains(&support) {
                break;
            }

            expanding_polytope.expand(support);
        }

        let minimal_face =
            Plane::from_points(expanding_polytope.face_vertices(expanding_polytope.minimal_face()));
        Some(epa::Collision {
            normal: minimal_face.normal,
            depth: minimal_face.displacement,
        })
    }

    pub fn sat(
        &self,
        other: &Rigid,
        polytope: &geometry::Polytope,
        #[allow(unused)] debug: &mut debug::DebugLines,
    ) -> bool {
        let self_face_query = sat::face_axes_separation((self, other), polytope);
        if self_face_query.0 >= 0.0 {
            return false;
        }

        let other_face_query = sat::face_axes_separation((other, self), polytope);
        if other_face_query.0 >= 0.0 {
            return false;
        }

        let edge_query = sat::edge_axes_separation((self, other), polytope, debug);
        if edge_query.0 >= 0.0 {
            return false;
        }

        if self_face_query.0 > edge_query.0 && other_face_query.0 > edge_query.0 {
            sat::face_contact((self, other), (self_face_query, other_face_query));
        } else {
            sat::edge_contact((self, other), edge_query);
        }

        true
    }
}
