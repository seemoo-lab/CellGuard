extern crate alloc;

mod csv_parser;

#[swift_bridge::bridge]
mod ffi {
    extern "Rust" {
        type RustApp;

        #[swift_bridge(init)]
        fn new() -> RustApp;

        fn parse_system_log(&self, input: &str, output: &str, high_volume_speedup: bool) -> u32;
    }

    extern "Swift" {
        fn swift_parse_trace_file(path: &str, count: u32);
    }
}

pub struct RustApp {}

impl RustApp {
    fn new() -> Self {
        RustApp {}
    }

    fn parse_system_log(&self, input: &str, output: &str, speedup: bool) -> u32 {
        csv_parser::output_header(output).unwrap();
        return csv_parser::parse_log_archive(input, output, speedup);
    }
}
