//! The infra tool: the whole lifecycle of a command-line tool on the engine, booted and logged, answering hello.

mod arch;
mod base;

use engine::error::Exit;

use crate::arch::Infra;

fn main () -> Exit {

    Exit::loud(Infra::run())

}
