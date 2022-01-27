# CRDevTools

## Development Tools for OTRS

From now on this tools are does not depends on the otrs.Console.pl, and does not need to be linked, but they must be called from an OTRS framework directory:

```sh
bin/cr.DevTools.pl Dev::<Object>::<Tool>
```

e.g.

```sh
~<OTRSHOME>$ /opt/CRDevTools/bin/cr.DevTools.pl Dev::ACL::Delete
```

or with a git alias like:

```conf
devtools = !/opt/CRDevTools/bin/cr.DevTools.pl
```

e.g.

```sh
~<OTRSHOME>$ git devtools Dev::ACL::Search
```

Use parameter --help to get more information on the options and general usage of each tool.

## Included Tools

### Delete Tools

#### Dev::ACL::Delete

* Delete ACLs from DB, also generates an ACL deployment to sync ZZZACL.pm file.

#### Dev::ChatChannel::Delete

* Delete chat channels from the DB
* Can delete associated chat messages

#### Dev::CustomerCompany::Delete

* Delete customer companies from the DB

#### Dev::CustomerUser::Delete

* Delete customer users from DB, also removes relations from **_&lt;CustomerUser Preferences Table&gt;_**
* **TODO: Delete group relations**

#### Dev::DynamicField::Delete

* Delete dynamic fields from DB, also removes field values.

#### Dev::FAQ::Delete

* Delete knowledge base articles from the DB

#### Dev::Group::Delete

* Delete groups from DB, also removes relations from *group_user* and *group_role*.
* **TODO: Delete CustomerUser relations**

#### Dev::Priority::Delete

* Delete ticket priorities from DB.
* Can delete associated tickets.

#### Dev::Process::Delete

* Delete processes from DB, also generates an process deployment to sync ZZZProcessManagement.pm file.

#### Dev::Process::DeleteTickets

* Delete process tickets from DB.

#### Dev::Process::Activity::Delete

* Delete process activities from the DB.

#### Dev::Process::ActivityDialog::Delete

* Delete process activity dialogs from the DB.

#### Dev::Process::SequenceFlow::Delete

* Delete process sequence flows from the DB.

#### Dev::Process::SequenceFlowAction::Delete

* Delete process sequence flow actions from the DB.

#### Dev::Queue::Delete

* Delete queues from DB, also removes relations from *personal_queues*, *queue_auto_response*, *queue_preferences* and *queue_standard_template*.
* Can delete associated tickets.

#### Dev::Service::Delete

* Delete services from DB, also removes relations from *service_customer_user*, *service_preferences*, *service_sla* and *personal_services*.
* Can delete associated tickets.

#### Dev::State::Delete

* Delete ticket states from DB.
* Can delete associated tickets.

#### Dev::Ticket::Delete

* Delete tickets from DB, including Articles and History (using OTRS API).
* Can delete all tickets at once (leaving initial ticket).

#### Dev::Type::Delete

* Delete ticket types from the DB.
* Can delete associated tickets.

#### Dev::User::Delete

* Delete users from DB, also removes relations from
*group_user*, *role_user*, *article_fag*, *ticket_history* and **_&lt;User Preferences Table&gt;_**
* **Warning:** As many tables are related to **_&lt;User Table&gt;_** before try to delete any user it is necessary to check if is not referenced by any other table.

### Search Tools

#### Dev::ACL::Search

* Search ACLs by name.

#### Dev::CustomerUser::Search

* Search customer users by login email or full-text (login first_name last_name).

#### Dev::DynamicField::Search

* Search dynamic fields by name.

#### Dev::Group::Search

* Search groups by name.

#### Dev::Priority::Search

* Search priorities by name.

#### Dev::Process::Search

* Search processes by name.

#### Dev::Queue::Search

* Search queues by name.

#### Dev::Service::Search

* Search services by name.

#### Dev::State::Search

* Search states by name.

#### Dev::Ticket::Search

* Search tickets by number, title customer owner or full-text (from to cc subject body).

#### Dev::Type::Search

* Search ticket types by name.

#### Dev::User::Search

* Search users by login email or full-text (login first_name last_name).

### General Tools

#### Dev::Process::Deploy

* Deploy all processes into Kernel/Config/Files/ZZZProcessManagement.pm

#### cr.DevProcessManagement: (deprecated)

* Import processes without changing the entity ID (raw import).
* Generate tickets for available processes using a random process and a random activity.

#### Note

This package is not intended to be used on production systems, please be aware of potential data lost.

Use it carefully and at your own risk, data deleted by included tools might be unrecoverable!
