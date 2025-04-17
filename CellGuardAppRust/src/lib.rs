#![allow(clippy::unnecessary_cast)]
extern crate alloc;

use std::backtrace::Backtrace;
use std::cell::Cell;
use std::path::Path;

// Smuggle backtrace for panic
// See: https://stackoverflow.com/a/73711057
thread_local! {
     static BACKTRACE: Cell<Option<Backtrace>> = const { Cell::new(None) };
}

mod csv_parser;

#[swift_bridge::bridge]
mod ffi {
    extern "Rust" {
        type RustApp;

        #[swift_bridge(init)]
        fn new() -> RustApp;

        fn parse_system_log(
            &self,
            input: &str,
            output: &str,
            high_volume_speedup: bool,
        ) -> (u32, String);
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

    fn parse_system_log(&self, input: &str, output: &str, speedup: bool) -> (u32, String) {
        // println! panics if io::stdout() changes or is not available anymore.
        // This is the case if XCode installs CellGuard to a device then losses the debug
        // connection, but the app remains active and Rust code is invoked.
        // See: https://github.com/chinedufn/swift-bridge/issues/291

        // With this temporary fix, we're catching the panic to prevent the crash.
        // See: https://doc.rust-lang.org/std/panic/fn.catch_unwind.html
        // See: https://stackoverflow.com/a/35559417

        std::panic::set_hook(Box::new(|_info| {
            // Smuggle the backtrace
            let trace = Backtrace::force_capture();
            BACKTRACE.set(Some(trace));
        }));

        let result = std::panic::catch_unwind(|| {
            csv_parser::parse_log_archive(Path::new(input), Path::new(output), speedup)
        });

        match result {
            Ok(i) => (i, "".to_owned()),
            Err(err) => {
                // Get cause of the panic
                // https://doc.rust-lang.org/std/macro.panic.html
                let panic_message = match err.downcast::<String>() {
                    Ok(string) => *string,
                    Err(panic) => {
                        format!("Unknown type: {:?}", panic)
                    }
                };

                // Get the backtrace
                let trace = BACKTRACE.take().unwrap();

                // Create error string
                (
                    u32::MAX,
                    format!("{}\n\n{}", panic_message, trace).to_string(),
                )
            }
        }
    }
}
