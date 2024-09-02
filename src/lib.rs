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
        // println! panics if io::stdout() changes or is not available anymore.
        // This is the case if XCode installs CellGuard to a device then losses the debug
        // connection, but the app remains active and Rust code is invoked.
        // TODO: Report this bug to swift-bridge

        // With this temporary fix, we're catching the panic to prevent the crash.
        // See: https://doc.rust-lang.org/std/panic/fn.catch_unwind.html
        // See: https://stackoverflow.com/a/35559417

        std::panic::set_hook(Box::new(|_info| {
            // This hook doesn't have to do anything
        }));

        let result = std::panic::catch_unwind(||  {
            csv_parser::output_header(output).unwrap();
            return csv_parser::parse_log_archive(input, output, speedup);
        });

        match result {
            Ok(i) => {i}
            Err(_) => {u32::MAX}
        }
    }
}
