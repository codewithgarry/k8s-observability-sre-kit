# Postmortem: <short title>

> **Blameless.** This document is about systems and processes, not people. Write "the deploy" rather than "Alex deployed".

| | |
|---|---|
| **Date** | YYYY-MM-DD |
| **Authors** | |
| **Status** | Draft / In review / Final |
| **Severity** | SEV1 / SEV2 / SEV3 |
| **Duration** | from first user impact to full recovery |
| **Error budget consumed** | % of the 30-day budget |

## Summary

Two or three sentences: what broke, who was affected, how it was fixed.

## Impact

- Users affected and how (errors, latency, data loss).
- SLO impact: error ratio peak, budget consumed.

## Timeline (UTC)

| Time | Event |
|---|---|
| hh:mm | Trigger (deploy, config change, traffic spike) |
| hh:mm | First user impact |
| hh:mm | Alert fired |
| hh:mm | On-call acknowledged |
| hh:mm | Mitigation applied |
| hh:mm | Full recovery confirmed |

## Root cause

What actually caused the failure. Use "5 whys" until you reach something that can be fixed in a system or process.

## Trigger

The specific event that exposed the root cause.

## Detection

How we found out. Did monitoring catch it before users did? How long was time to detect?

## Resolution

What restored service, and why it worked.

## What went well

## What went wrong

## Where we got lucky

## Action items

| # | Action | Type | Owner | Priority | Ticket |
|---|---|---|---|---|---|
| 1 | | prevent / detect / mitigate / process | | P1 / P2 / P3 | |

## Lessons learned
