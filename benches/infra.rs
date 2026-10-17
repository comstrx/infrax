//! Scenario: what the real `infra` binary costs to boot and answer `doctor`, and what its plumbing costs alone.

use criterion::{Criterion, criterion_group, criterion_main};
use engine::process::{Args, Cargo, Provider, Spec};
use core::hint::black_box;
use std::path::Path;

fn bench_infra ( harness: &mut Criterion ) {

    let mut group = harness.benchmark_group("infra");
    let spec      = Spec::new("iam", "/opt/iam/bin/iam").arg("--serve");

    if let Ok(mut doctor) = Cargo::command(Path::new(env!("CARGO_MANIFEST_DIR")), "infra", true, "INFRA_") {

        doctor.arg("doctor");
        group.bench_function("doctor", |bencher| bencher.iter(|| doctor.output().map(|output| output.status.success())));

    }

    group.bench_function("args/parse", |bencher| bencher.iter(|| Args::from_words(black_box(&["infra", "service", "status", "iam", "--provider", "systemd"])).command().map(str::len)));
    group.bench_function("spec/render", |bencher| bencher.iter(|| black_box(&spec).render(Provider::Systemd).len()));
    group.finish();

}

criterion_group!(benches, bench_infra);
criterion_main!(benches);
