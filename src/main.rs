//! The infrastructure tool: what this machine is, its services and its packages, driven by the engine.

mod arch;
mod base;
mod faults;
mod doctor;
mod package;
mod service;

use engine::error::Exit;

use crate::arch::Infra;

fn main () -> Exit {

    Exit::loud(Infra::run())

}
