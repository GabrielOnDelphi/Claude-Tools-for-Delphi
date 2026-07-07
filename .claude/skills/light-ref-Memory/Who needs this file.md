
Who reads light-ref-Memory\SKILL.md � exactly 4 readers:

1. You (/light-ref-Memory) � manual load, while coding.
2. The auto skill-loader � may load it when your prompt is about lifetimes/exceptions.
3. light-review-step1 agent � Reads it during a review (pointer I wired in).
4. light-review-step3 agent � Reads it when verifying fixes.

Who does NOT read it: the light-review-Full skill. It only launches agents � it never touches the file. The line I just added there is a signpost for a human opening that skill, nothing reads it at runtime.

So: 1�2 are the coding-time use; 3�4 are the review use. One file, four readers.