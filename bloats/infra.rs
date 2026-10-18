//! The floor the `infra` binary pays: the engine crates linked the way it links them.

use engine::memory::{Simd, Space as _, Stack};
use engine::error::{Code, Failure};
use engine::log::{Log, Stderr};
use engine::process::{Args, Tool};
use core::hint::black_box;
use std::env::args_os;

fn main () {

    let log = Log::setup().sink(Stderr::json()).build("bloat");

    let mut line = Stack::<32>::new();

    black_box(line.push_str("Hello, world!").map(|line| line.len()).ok());
    black_box(Simd::find(&line, b','));
    black_box(Failure::ensure(args_os().count() == 1, Code::Usage, "no arguments").err().map(|failure| failure.report().to_string()));
    black_box(log.info("linked").field("bytes", line.len()).commit().ok());
    black_box(Tool::new(Args::current(), log, "bloat hello").command().map(str::len).ok());

}
