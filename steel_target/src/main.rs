
fn main() {
    steel::steel_vm::engine::Engine::execute_non_interactive_program_image(include_bytes!("program.bin"));
}
            