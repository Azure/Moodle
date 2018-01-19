# Contributing to Moodle on Azure 

This project welcomes contributions and suggestions. Our goal is to
work on Azure specific tooling for deploying and managing the open
source [Moodle](http://moodle.org) learning management system on
Azure. We do not work on Moodle itself here, instead we work upstream
as appropriate.

The short version of how to contribute to this project is "just do
it". Where "it" can be defined as any valuable contribution (and to be
clear, asking questions is a valuable contribution):

  * ask questions
  * provide feedback
  * write or update documentation
  * help new users
  * recommend the project to others
  * test the code and report bugs
  * fix bugs and issue pull requests
  * give us feedback on required features
  * write and update the software
  * create artwork
  * translate to different languages
  * anything you can see that needs doing

Most contributions require you to agree to a Contributor License
Agreement (CLA) declaring that you have the right to, and actually do,
grant us the rights to use your contribution. For details, visit
https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine
whether you need to provide a CLA and decorate the PR appropriately
(e.g., label, comment). Simply follow the instructions provided by the
bot. You will only need to do this once across all repos using our
CLA.

# Planning

This is an open source project. We have a few mantras to ensure
efficient collaboration, these mostly boil down to ensuring good
visibility into the communities goals. These include:

  * If it didn't happen in public, it didn't happen
  * Scratch your own itch
  
## If it didn't happen in public, it didn't happen (aka full transparency)

The goal of this mantra is to ensure maximum visibility into our
communities work in order to:

  1. Provide an opportunity for community feedback in order to ensure
     our plans are good
  2. Provide a clear indication of what will be done, what may be done
     and what won't be done
  
Both of these goals lead to the second mantra "Scratch your own itch".

## Scratch your own itch (aka getting what you want)

This is an open source project. We welcome feature requests and, as a
community, we will provide feedback on whether we intend to work on it
or not. To this end we categories feature requests in one of 4 ways:

  * Priority 0 (will address)
  * Priority 1 (may address)
  * Priority 2 (maybe one day)
  * wontfix (out of scope)

Using these priorities it is easy for community members to decide
where to spend their time. For example:

  * Priority 0 items are actively being worked on by at least one
    community member. Others are welcome to contribute as appropriate
    (reviews are particularly important)
  * Priority 1 items are seen as important and are likely to be worked
    on in the short to medium term, but there is no community member
    active on the project at this time. Community members are welcome
    to take ownership of these issues and propose a solution that they
    intend to implement. If the community accepts the proposal then it
    will become a Priority 0 issue.
  * Priority 2 items are seen as interesting proposals that are not in
    conflict with the projects goals but are unlikely to be worked on
    by any existing communty members. Community members who have a
    need for these items are strongly encouraged to identify
    themselves and offer a proposal for a solution. If there is enough
    support within the existing community this item can become a
    Priority 0 under your leadership.
  * Wontfix items are considered out of scope for this project.
    Community members should seek to solve the problem in different
    ways. Often this will mean contribution to Moodle itself or a
    plugin that is external to this community.

# Community roles

This section outlines roles and responsibilities within the community.

## Users

Users self-identify by using our software and documentation. Their
responsibilities are to benefit from our work, but we welcome
contributions from users, such as:

  * Ask questions
  * Answer questions
  * Feature requests
  * Bug reports
  * Design reviews
  * Planning reviews
  * Evangelize the project
  * and more...
  
Some users will become more involved with the project, those users
become Contributors.

## Contributors

Contributes self-identify by making longer term commitments to our
project. Their responsibilities are to help the project be succesful
by ensuring that our work matches the needs of our users.
Possible contributions can include:

  * Everything a User might contribute
  * Remove blocks for users
  * Provide design input
  * Review pull requests
  * Implement features
  * Triage questions, feature requests and bug reports
  * and more...
  
Some contributors will become very engaged and therefore become an
essential part of the community, these contributors will become
Maintainers.

## Maintainers

We are fans of efficient processes. Maintainers are people who insert
themselves into our process to ensure they run well. The goal is to
empower our contributors who in turn focus on delighting our users.
Maintainers contributions may include:

  * Everyting Users and Contributors do
  * Merge pull requests where appropriate
  * Seek community consensus where conflict occurs
  * Remove blocks for contributors
  * and more...

# Pull requests, Review and Merges

We like efficient processes. Anyone is welcome to issue pull requests.
Everyone is encouraged to review pull requests. Maintainers are
responsible for merging pull requests but they are not responsible for
reviews, that is a community wide responsibility.

We operate under two models of review process as appropriate to each
circumstance:

  * Merge then Review (our preferred model)
  * Review then Merge
  
## Merge Then Review

In the "merge then review" model a maintainer will merge the pull
request into with minimal review. Community members are still expected
to review the code, but it is done after the fact.

The goal is to get the code into a shared repository as early as
possible. This allows people, including advanced users, to start
testing it. This ensures we have the maximum possible exposure to
testing in real scenarios early in the process. Encouragin bug reports
from the whole community ensures we have visibility into breaks as
early as possible.

This model has its risks, however. If a PR is on the critical path or
it is controversial in some way it is expected that maintainers will
ensure it recieves a thorough review before merging (see next section
on "Review then Merge". This decision is at the discretion of the
maintainer who first triages the pull request.

Should a mistake be made and a bad merge be performed then it can
often be easier and faster to fix it under the "Merge then Review"
model than it is to provide feedback to the original author and await
a fix from them. Should the mistake have a high impact and/or no easy
fix is available we simply roll back the merge and provide feedback
via the review process.

It should be noted that this model means that maintainers have the
right to simply merge their own code and expect others to review it
*after*. Maintainers are expected to use their best judgement when
excercising this priviledge.

## Review Then Merge

Where a change is on the critical path or it is potentiall
contriversial maintainers should request reviews using the GitHub
tooling. The last reviewer to sign-off on the pull request will merge
the pull request.
