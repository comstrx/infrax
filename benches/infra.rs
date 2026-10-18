//! Scenario: what the real `infra` binary costs to boot and say hello, and what its argument parsing costs alone.

use criterion::{Criterion, criterion_group, criterion_main};
use engine::process::{Args, Cargo};
use core::hint::black_box;
use std::path::Path;

fn bench_infra ( harness: &mut Criterion ) {

    let mut group = harness.benchmark_group("infra");

    if let Ok(mut hello) = Cargo::command(Path::new(env!("CARGO_MANIFEST_DIR")), "infra", true, "INFRA_") {

        hello.arg("hello");
        group.bench_function("hello", |bencher| bencher.iter(|| hello.output().map(|output| output.status.success())));

    }

    group.bench_function("args/parse", |bencher| bencher.iter(|| Args::from_words(black_box(&["infra", "hello", "--INFRA_LOG=info"])).command().map(str::len)));
    group.finish();

}

criterion_group!(benches, bench_infra);
criterion_main!(benches);
