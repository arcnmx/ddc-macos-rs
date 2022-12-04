#![doc(html_root_url = "https://docs.rs/ddc-macos/0.2.0/")]

//! Implementation of DDC/CI traits on MacOS.
//!
//! # Example
//!
//! ```rust,no_run
//! # fn main() {
//! use ddc::Ddc;
//! use ddc_macos::Monitor;
//!
//! for mut ddc in Monitor::enumerate().unwrap() {
//!     let input = ddc.get_vcp_feature(0x60).unwrap();
//!     println!("Current input: {:04x}", input.value());
//! }
//! # }
//! ```

mod iokit;
mod monitor;

pub use monitor::*;
