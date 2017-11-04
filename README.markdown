# CRDevTools

## Development Tools for OTRS
From now on this tools are does not depends on the otrs.Console.pl, and does not need to be linked, but they must be called from an OTRS framework directory:

```perl
bin/cr.DevTools.pl Dev::<Object>::<Tool>
```
e.g.

```sh
/opt/CRDevTools/bin/cr.DevTools.pl Dev::ACL::Delete
```

Git alias
```
devtools = !~/Dev/CR/CRDevTools/bin/cr.DevTools.pl
```
e.g.

```sh
git devtools Dev::ACL::Search
```

Use parameter --help to get more information on the options and general usage of each tool.

## Included Tools:

### Delete Tools:
* Dev::ACL::Delete:

  Delete ACLs from DB, also generates an ACL deployment to sync ZZZACL.pm file.

* Dev::CustomerUser::Delete:

  Delete customer users from DB, also removes relations from **_&lt;CustomerUser Preferences Table&gt;_**

  **TODO: Delete group relations**

* Dev::Group::Delete:

  Delete groups from DB, also removes relations from _group_user_ and _group_role_.

  **TODO: Delete CustomerUser relations**

* Dev::Priority::Delete:

  Delete ticket priorities from DB.

  Can delete associated tickets.

* Dev::Process::Delete:

  Delete processes from DB, also generates an process deployment to sync ZZZProcessManagement.pm file.

* Dev::Queue::Delete:

  Delete queues from DB, also removes relations from _personal_queues_, _queue_auto_response_, _queue_perferences_ and _queue_standard_template_.

  Can delete associated tickets.

* Dev::Service::Delete:

  Delete services from DB, also removes relations from _service_customer_user_, _service_preferences_, _service_sla_ and _personal_services_.

  Can delete associated tickets.

* Dev::State::Delete:

  Delete ticket states from DB.

  Can delete associated tickets.

* Dev::Ticket::Delete:

   Delete tickets from DB, including Articles and History (using OTRS API).

   Can delete all tickets at once (leaving initial ticket).

* Dev::Type::Delete:

   Delete ticket types from the DB.

   Can delete associated tickets.

* Dev::User::Delete:

  Delete users from DB, also removes relations from _group_user_, _role_user_, _article_fag_, _ticket_history_ and **_&lt;User Preferences Table&gt;_**

  **Warning:** As many tables are related to **_&lt;User Table&gt;_** before try to delete any user it is necessary to check if is not referenced by any other table.

### Search Tools:
* Dev::Ticket::Search

  Search tickets by number, title customer owner or full-text (from to cc subject body).

### General Tools:

* cr.DevProcessManagement:

   Import processes without changing the entity ID (raw import).

   Deletes all process Tickets from the DB.

   Deletes all processes from DB.

   Deploy processes.

   Generate tickets for available processes using a random process and a random activity.

#### Note:
This package is not intended to be use on production systems, please be aware of potential data lost.

Use it carefully and at your own risk, data deleted by included tools might be unrecoverable!
