// Copyright 2022 Mandiant, Inc. All Rights Reserved
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software distributed under the License
// is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and limitations under the License.

use std::error::Error;
use std::fs;
use std::fs::OpenOptions;
use std::path::PathBuf;
use macos_unifiedlogs::dsc::SharedCacheStrings;
use macos_unifiedlogs::parser::{
    build_log, collect_shared_strings, collect_strings, collect_timesync, parse_log,
};
use macos_unifiedlogs::timesync::TimesyncBoot;
use macos_unifiedlogs::unified_log::{LogData, UnifiedLogData};
use macos_unifiedlogs::uuidtext::UUIDText;
use crate::ffi;

// Parse a provided directory path. Currently expect the path to follow macOS log collect structure
pub fn parse_log_archive(path: &str, output_path: &str) -> u32 {
    let mut archive_path = PathBuf::from(path);

    // Parse all UUID files which contain strings and other metadata
    let string_results = collect_strings(&archive_path.display().to_string()).unwrap();

    archive_path.push("dsc");
    // Parse UUID cache files which also contain strings and other metadata
    let shared_strings_results =
        collect_shared_strings(&archive_path.display().to_string()).unwrap();
    archive_path.pop();

    archive_path.push("timesync");
    // Parse all timesync files
    let timesync_data = collect_timesync(&archive_path.display().to_string()).unwrap();
    archive_path.pop();

    // Keep UUID, UUID cache, timesync files in memory while we parse all tracev3 files
    // Allows for faster lookups
    let log_count = parse_trace_file(
        &string_results,
        &shared_strings_results,
        &timesync_data,
        path,
        output_path,
    );

    println!("\nFinished parsing Unified Log data. Saved results to: output.csv");
    return log_count
}

// Use the provided strings, shared strings, timesync data to parse the Unified Log data at provided path.
// Currently expect the path to follow macOS log collect structure
fn parse_trace_file(
    string_results: &[UUIDText],
    shared_strings_results: &[SharedCacheStrings],
    timesync_data: &[TimesyncBoot],
    path: &str,
    output_path: &str,
) -> u32 {
    // We need to persist the Oversize log entries (they contain large strings that don't fit in normal log entries)
    // Some log entries have Oversize strings located in different tracev3 files.
    // This is very rare. Seen in ~20 log entries out of ~700,000. Seen in ~700 out of ~18 million
    let mut oversize_strings = UnifiedLogData {
        header: Vec::new(),
        catalog_data: Vec::new(),
        oversize: Vec::new(),
    };

    // Exclude missing data from returned output. Keep separate until we parse all oversize entries.
    // Then at end, go through all missing data and check all parsed oversize entries again
    let mut exclude_missing = true;
    let mut missing_data: Vec<UnifiedLogData> = Vec::new();

    let mut archive_path = PathBuf::from(path);
    archive_path.push("Persist");

    let mut log_count: usize = 0;
    if archive_path.exists() {
        let paths = fs::read_dir(&archive_path).unwrap();

        // Loop through all tracev3 files in Persist directory
        for log_path in paths {
            let data = log_path.unwrap();
            let full_path = data.path().display().to_string();
            println!("Parsing: {}", full_path);
            ffi::swift_parse_trace_file(full_path.as_str(), u32::try_from(log_count).unwrap_or(0));

            let log_data = if data.path().exists() {
                parse_log(&full_path).unwrap()
            } else {
                println!("File {} no longer on disk", full_path);
                continue;
            };

            // Get all constructed logs and any log data that failed to get constrcuted (exclude_missing = true)
            let (results, missing_logs) = build_log(
                &log_data,
                string_results,
                shared_strings_results,
                timesync_data,
                exclude_missing,
            );
            // Track Oversize entries
            oversize_strings
                .oversize
                .append(&mut log_data.oversize.to_owned());

            // Track missing logs
            missing_data.push(missing_logs);
            log_count += results.len();
            output(&results, output_path).unwrap();
        }
    }

    archive_path.pop();
    archive_path.push("Special");

    if archive_path.exists() {
        let paths = fs::read_dir(&archive_path).unwrap();

        // Loop through all tracev3 files in Special directory
        for log_path in paths {
            let data = log_path.unwrap();
            let full_path = data.path().display().to_string();
            println!("Parsing: {}", full_path);
            ffi::swift_parse_trace_file(full_path.as_str(), u32::try_from(log_count).unwrap_or(0));

            let mut log_data = if data.path().exists() {
                parse_log(&full_path).unwrap()
            } else {
                println!("File {} no longer on disk", full_path);
                continue;
            };

            // Append our old Oversize entries in case these logs point to other Oversize entries the previous tracev3 files
            log_data.oversize.append(&mut oversize_strings.oversize);
            let (results, missing_logs) = build_log(
                &log_data,
                string_results,
                shared_strings_results,
                timesync_data,
                exclude_missing,
            );
            // Track Oversize entries
            oversize_strings.oversize = log_data.oversize;
            // Track missing logs
            missing_data.push(missing_logs);
            log_count += results.len();

            output(&results, output_path).unwrap();
        }
    }

    archive_path.pop();
    archive_path.push("Signpost");

    if archive_path.exists() {
        let paths = fs::read_dir(&archive_path).unwrap();

        // Loop through all tracev3 files in Signpost directory
        for log_path in paths {
            let data = log_path.unwrap();
            let full_path = data.path().display().to_string();
            println!("Parsing: {}", full_path);
            ffi::swift_parse_trace_file(full_path.as_str(), u32::try_from(log_count).unwrap_or(0));

            let log_data = if data.path().exists() {
                parse_log(&full_path).unwrap()
            } else {
                println!("File {} no longer on disk", full_path);
                continue;
            };

            let (results, missing_logs) = build_log(
                &log_data,
                string_results,
                shared_strings_results,
                timesync_data,
                exclude_missing,
            );

            // Signposts have not been seen with Oversize entries
            missing_data.push(missing_logs);
            log_count += results.len();

            output(&results, output_path).unwrap();
        }
    }
    archive_path.pop();
    archive_path.push("HighVolume");

    if archive_path.exists() {
        let paths = fs::read_dir(&archive_path).unwrap();

        // Loop through all tracev3 files in HighVolume directory
        for log_path in paths {
            let data = log_path.unwrap();
            let full_path = data.path().display().to_string();
            println!("Parsing: {}", full_path);
            ffi::swift_parse_trace_file(full_path.as_str(), u32::try_from(log_count).unwrap_or(0));

            let mut log_data = if data.path().exists() {
                parse_log(&full_path).unwrap()
            } else {
                println!("File {} no longer on disk", full_path);
                continue;
            };

            // Append our old Oversize entries in case these logs point to other Oversize entries the previous tracev3 files
            log_data.oversize.append(&mut oversize_strings.oversize);
            let (results, missing_logs) = build_log(
                &log_data,
                string_results,
                shared_strings_results,
                timesync_data,
                exclude_missing,
            );

            // Track Oversize entries
            oversize_strings.oversize = log_data.oversize;
            missing_data.push(missing_logs);
            log_count += results.len();

            output(&results, output_path).unwrap();
        }
    }
    archive_path.pop();

    archive_path.push("logdata.LiveData.tracev3");

    // Check if livedata exists. We only have it if 'log collect' was used
    if archive_path.exists() {
        println!("Parsing: logdata.LiveData.tracev3");
        let mut log_data = parse_log(&archive_path.display().to_string()).unwrap();
        log_data.oversize.append(&mut oversize_strings.oversize);
        let (results, missing_logs) = build_log(
            &log_data,
            string_results,
            shared_strings_results,
            timesync_data,
            exclude_missing,
        );
        // Track missing data
        missing_data.push(missing_logs);
        log_count += results.len();

        output(&results, output_path).unwrap();
        // Track oversize entries
        oversize_strings.oversize = log_data.oversize;
        archive_path.pop();
    }

    exclude_missing = false;

    // Since we have all Oversize entries now. Go through any log entries that we were not able to build before
    for mut leftover_data in missing_data {
        // Add all of our previous oversize data to logs for lookups
        leftover_data
            .oversize
            .append(&mut oversize_strings.oversize.to_owned());

        // Exclude_missing = false
        // If we fail to find any missing data its probably due to the logs rolling
        // Ex: tracev3A rolls, tracev3B references Oversize entry in tracev3A will trigger missing data since tracev3A is gone
        let (results, _) = build_log(
            &leftover_data,
            string_results,
            shared_strings_results,
            timesync_data,
            exclude_missing,
        );
        log_count += results.len();

        output(&results, output_path).unwrap();
    }
    println!("Parsed {} log entries", log_count);

    return u32::try_from(log_count).unwrap_or(0);
}

// Create csv file and create headers
pub fn output_header(file: &str) -> Result<(), Box<dyn Error>> {
    let csv_file = OpenOptions::new()
        .append(true)
        .create(true)
        .open(file)?;
    let mut writer = csv::Writer::from_writer(csv_file);

    writer.write_record(&[
        "Timestamp",
        "Event Type",
        "Log Type",
        "Subsystem",
        "Thread ID",
        "PID",
        "EUID",
        "Library",
        "Library UUID",
        "Activity ID",
        "Category",
        "Process",
        "Process UUID",
        "Message",
        "Raw Message",
        "Boot UUID",
        "System Timezone Name",
    ])?;
    Ok(())
}

// Append or create csv file
fn output(results: &Vec<LogData>, file: &str) -> Result<(), Box<dyn Error>> {
    let csv_file = OpenOptions::new()
        .append(true)
        .create(true)
        .open(file)?;
    let mut writer = csv::Writer::from_writer(csv_file);

    // Pre-scan the log entries written to the CSV file, so that the file is smaller and Swift can parse it faster
    const PROCESSES: [&str; 1] = [
        "/System/Library/Frameworks/CoreTelephony.framework/Support/CommCenter",
        // "/usr/sbin/WirelessRadioManagerd"
    ];
    const SUBSYSTEMS: [&str; 2] = [
        "com.apple.telephony.bb",
        "com.apple.CommCenter"
    ];
    const CONTENTS: [&str; 2] = [
        "kCTCellMonitorCellRadioAccessTechnology",
        "Bin="
    ];


    results.iter()
        .filter(|data| {
            if !PROCESSES.contains(&data.process.as_str()) {
                return false;
            }

            if !SUBSYSTEMS.contains(&data.subsystem.as_str()) {
                return false;
            }

            for content_query in &CONTENTS {
                if data.message.contains(content_query) {
                    return true;
                }
            }

            return false;
        })
        .for_each(|data| {
            writer.write_record(&[
                data.time.to_string(),
                data.event_type.to_owned(),
                data.log_type.to_owned(),
                data.subsystem.to_owned(),
                data.thread_id.to_string(),
                data.pid.to_string(),
                data.euid.to_string(),
                data.library.to_owned(),
                data.library_uuid.to_owned(),
                data.activity_id.to_string(),
                data.category.to_owned(),
                data.process.to_owned(),
                data.process_uuid.to_owned(),
                data.message.to_owned(),
                data.raw_message.to_owned(),
                data.boot_uuid.to_owned(),
                data.timezone_name.to_owned(),
            ]).unwrap();
        });

    Ok(())
}