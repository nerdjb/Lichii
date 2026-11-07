# AMD frame-generation patches

These are the three commits from [chuppatricky/Lichii](https://github.com/chuppatricky/Lichii)
(`chuppatricky-amd-testbuild-v14-source`) that are not in `zortos293/Lichii@nx2`, plus one small
prerequisite:

1. `present: log when frame generation runs or why it can't`
2. `frame_gen: space generated frames over the game frame's time`
3. `frame_gen: find large motion in the built-in frame generation`
4. `present: allow extra image usage flags for wrapped images` (the `extra_usage` parameter; the
   large-motion rewrite needs it, and its original commit is already upstream without it)

They are rebased onto upstream `nx2` commit `89440b29a9` and are the content of the branch commits
with the same subjects. The `upstream-sync` workflow normally merges upstream into
`nx2-amd-framegen`; these patches are kept so the frame-generation change can be re-applied to a
fresh upstream without the rest of this fork:

```sh
git switch -c amd-framegen upstream/nx2
git am -3 patches/amd-framegen/*.patch
```

`0003` is a rewrite of `src/video_core/renderer_vulkan/present/fsr3_frame_gen.*` and replaces
`fsr3_optical_flow.comp` with the `fg_*.comp` shader passes. If upstream later changes the same
file, a conflict there is expected; resolve it keeping upstream's newer structure and the motion
pyramid from these patches.
