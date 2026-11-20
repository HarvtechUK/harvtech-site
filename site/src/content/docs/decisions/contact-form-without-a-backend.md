---
title: A contact form with no backend
description: Why the request-a-call form writes an email in the visitor's own email app instead of posting to a server.
category: decisions
order: 60
updated: 2026-11-20
status: living
---

## Context

The site needed a proper call to action: a form a visitor can fill in to ask for a call, alongside email and a phone number.

The site is static files in Azure Storage behind Front Door. There is nothing to post a form to. Adding somewhere to post it means choosing between:

- **A third-party form service.** Quick, but a prospect's name, company and phone number pass through a company we would then have to name as a processor in the privacy policy. For a firm selling to regulated insurers that is a poor first impression.
- **An endpoint on the client portal.** The portal already runs and already notifies us. But it holds client reports, and a public, unauthenticated endpoint that accepts free text is exactly the kind of surface we would rather it did not have.
- **A new Azure Function or Logic App.** More infrastructure to run, monitor and pay for, plus spam handling, to move a handful of messages a month.

## Decision

The form does not post anywhere. Pressing the button runs a few lines of script that turn the answers into an email (a `mailto:` link with the subject and body filled in) and hand it to the visitor's own email app. They press send.

For anyone whose email app does not open, the same message appears on the page with a copy button and the address to send it to.

## What this buys

- **Nothing typed into the form reaches this website.** There is nothing to store, secure, back up or delete, and the privacy policy's statement that the site collects no data stays true without a footnote.
- **No third party** sees a prospect's details.
- **No spam.** There is no endpoint for a bot to post to.
- **The reply-to address is always right**, because the email comes from the visitor's own account.
- No running cost and nothing to monitor.

## What it costs

- It depends on the visitor having an email app set up. Most people at work do; the copy-and-send fallback covers the rest, at the price of one extra step.
- We cannot count submissions, because we never see one until the email arrives. That is acceptable at this volume.
- It needs JavaScript. Without it the page says so and shows the email address.

## Phone and booking

A phone number and a self-service booking page are both supported and both optional. They live in `site/src/data/contact.ts`; while a value is empty the site does not show that option at all, so there is never a placeholder on the live site.

## When to revisit

If enquiries grow to the point where losing one to a missing email app matters, or a booking page proves to convert better, replace the form's script with a post to a small endpoint and update the privacy policy in the same change.
