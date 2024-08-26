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

```shell
 Dev::ACL::Delete                         - Delete one or more ACLs.
 Dev::ACL::Search                         - Search ACLs in the system.
 Dev::ChatChannel::Delete                 - Delete one or more chat channels.
 Dev::ChatChannel::Search                 - Search Chat Channels in the system.
 Dev::Code::Class::Usage                  - Find class usage, listing all methods, results are printed on the screen in markdown format.
 Dev::Config::InlineEditing               - Set / Unset Inline Editing for properties in business objects detail views.
 Dev::CustomerCompany::Delete             - Delete one or more Customer Companies.
 Dev::CustomerCompany::Search             - Search Customer Companies in the system.
 Dev::CustomerUser::Delete                - Delete one or more Customer Users.
 Dev::CustomerUser::Search                - Search Customer Users in the system.
 Dev::DynamicField::Delete                - Delete one or more Dynamic Fields.
 Dev::DynamicField::Search                - Search Dynamic Fields in the system.
 Dev::FAQ::Delete                         - Delete one or more FAQs.
 Dev::FAQ::Search                         - Search FAQ items in the system.
 Dev::GeneralCatalog::Delete              - Delete one or more GeneralCatalogs.
 Dev::GeneralCatalog::Search              - Search GeneralCatalogs in the system.
 Dev::Git::Branch::Cleanup                - Remove local branches where remote has already gone.
 Dev::Group::Delete                       - Delete one or more Groups.
 Dev::Group::Search                       - Search Groups in the system.
 Dev::ITSMConfigItem::Delete              - Delete one or more ITSM Config Items.
 Dev::ITSMConfigItem::Search              - Search ITSMConfigItem in the system.
 Dev::ITSMConfigItem::Definition::Delete  - Delete one or more ITSMConfigItem Definitions.
 Dev::ITSMConfigItem::Definition::Search  - Search ITSM ConfigItem Definitions in the system.
 Dev::LDAP::Group::Generate               - Generate LDAP Groups with members definitions for LDIF and OTRS config.
 Dev::Module::MinimumFramework::Set       - Set minimum framework version for a module or modules.
 Dev::Module::UnitTest::Run               - Execute unit tests from a module.
 Dev::Priority::Delete                    - Delete one or more priorities.
 Dev::Priority::Search                    - Search Priorities in the system.
 Dev::ProcessManagement::DeleteProcessTickets - Delete All Processes Tickets.
 Dev::ProcessManagement::Deploy           - Deploy Processes.
 Dev::ProcessManagement::Activity::Delete - Delete one or more Process Management Activities.
 Dev::ProcessManagement::Activity::Search - Search Process Management Activities in the system.
 Dev::ProcessManagement::ActivityDialog::Delete - Delete one or more Process Management Activity Dialogs.
 Dev::ProcessManagement::ActivityDialog::Search - Search Process Management Activity Dialogs in the system.
 Dev::ProcessManagement::Process::Delete  - Delete one or more Process Management Processes.
 Dev::ProcessManagement::Process::Search  - Search Process Management Processes in the system.
 Dev::ProcessManagement::SequenceFlow::Delete - Delete one or more Process Management Sequence Flows.
 Dev::ProcessManagement::SequenceFlow::Search - Search Process Management Sequence Flows in the system.
 Dev::ProcessManagement::SequenceFlowAction::Delete - Delete one or more Process Management Sequence Flow Actions.
 Dev::ProcessManagement::SequenceFlowAction::Search - Search Process Management Sequence Flow Actions in the system.
 Dev::Queue::Delete                       - Delete one or more queues.
 Dev::Queue::Search                       - Search queues in the system.
 Dev::Role::Delete                        - Delete one or more Roles.
 Dev::Role::Search                        - Search Roles in the system.
 Dev::Salutation::Delete                  - Delete one or more Salutations.
 Dev::Salutation::Search                  - Search Salutations in the system.
 Dev::Service::Delete                     - Delete one or more services.
 Dev::Service::Search                     - Search Services in the system.
 Dev::Signature::Delete                   - Delete one or more Signatures.
 Dev::Signature::Search                   - Search Signatures in the system.
 Dev::State::Delete                       - Delete one or more ticket states.
 Dev::State::Search                       - Search States in the system.
 Dev::SystemAddress::Delete               - Delete one or more system addresses.
 Dev::SystemAddress::Search               - Search SystemAddresses in the system.
 Dev::Ticket::Archive                     - Archive one or more Tickets.
 Dev::Ticket::Delete                      - Delete one or more Tickets.
 Dev::Ticket::Search                      - Search Tickets in the system.
 Dev::Type::Delete                        - Delete one or more Ticket Types.
 Dev::Type::Search                        - Search Ticket Types in the system.
 Dev::User::Delete                        - Delete one or more Users.
 Dev::User::Search                        - Search Users in the system.
```

## Note

This package is not intended to be used on production systems, please be aware of potential data lost.

Use it carefully and at your own risk, data deleted by included tools might be unrecoverable!
