---
status: "maintained"
owner: "agent workflow; the user owns their answers"
read_when: "starting a session, answering a question, or processing edited answers"
update_when: "the decision workflow needs clarification; questions belong in separate files"
retire_when: "a replacement workflow is agreed and all outstanding answers are transferred"
---

# Decision Inbox

When a researched choice genuinely needs your input, the agent puts a Markdown
file here and links it in the conversation. Edit its **Your answer** section,
then tell the agent that your answers are ready. Files are processed during an
active session, not automatically in the background.

There is no need to supply electrical limits the agent can derive. Precision-first
design and reuse of proven circuit approaches are already settled priorities.
Questions should concern your intended musical use or a concrete cost, scope,
architecture or purchase tradeoff supported by evidence. Recommendations are not
preselected approvals. Do not put passwords, payment details or other secrets here.

## File Format

Use one decision per `YYYY-MM-DD-topic.md`. The following is an example format,
not an unanswered decision; create a file only when its prerequisites exist.

```markdown
---
status: "pending"
owner: "user answer; agent research and integration"
read_when: "working on the affected module or after the user edits this file"
update_when: "the user answers, evidence changes, or the agent records the outcome"
retire_when: "the answer and rationale are integrated and the resulting work is checkpointed"
---

# Short Decision Title

## Decision Needed

One concrete question, why it matters, and what work depends on it.
Link to the authoritative requirement and supporting evidence.

## Options And Recommendation

Explain meaningful alternatives, cost/scope implications, and the recommendation.
For a number, specify units, range and consequences. State anything still unknown.
Name the acceptance check for the chosen option and any purchase boundary.

## Your Answer

Choice or number (include units):

Notes or constraints:

Ready for integration: no

## Processing Record

Agent interpretation, any remaining question, affected documents and validation.
Leave empty until the user supplies an answer.
```

## Processing And Retirement

1. The user edits **Your Answer** and sets **Ready for integration** to `yes`
   when finished. An explicit instruction in conversation can also authorize
   processing; the agent records it without pretending the user edited the file.
2. The agent reads the answers before changing the affected design. If anything
   consequential is unclear, it records the specific follow-up here, marks the
   file `blocked`, and asks the user to finish that answer. Other independent
   work can continue.
3. The agent records the decision and its rationale in the owning spec or
   roadmap, implements the approved scope, runs the named checks, and commits
   and pushes the checkpoint. Retain the user's answer or a faithful attributed
   record in that checkpoint before deleting an inbox file.
4. Once the decision is integrated, delete the processed file rather than
   accumulate closed questions. Its durable home and Git history retain the
   outcome. A blocked file stays with an explicit next trigger, not a stale
   claim of completion.

The files beside this README are the inbox; no parallel checklist is maintained.