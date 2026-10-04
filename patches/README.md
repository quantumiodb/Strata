# Local patches to the vendored llama.cpp (third_party/llama.cpp is gitignored; setup re-fetches it)

- `ggml-iq2-iq3-dpwssd-avxvnni.patch`: in the AVX2 paths of `ggml_vec_dot_iq2_xxs/iq2_s/iq3_xxs/iq3_s_q8_K`,
  fold `madd_epi16 + add_epi32` into one `vpdpwssd` under `__AVXVNNI__`. Bit-exact (same int32 math).
  Measured on an i7-12700K + RTX A4000 (2026-10-05): no end-to-end change (66-67 tok/s either way) because the
  dot's time is in the iq2s_grid gathers and sign unpacking, not the MACs, and the CPU is not the bottleneck.
  Apply with: `patch -d third_party/llama.cpp -p1 < patches/ggml-iq2-iq3-dpwssd-avxvnni.patch` (the vendored tree is not a git checkout)
