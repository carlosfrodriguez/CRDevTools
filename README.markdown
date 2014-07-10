#CRDevTools

###Development Tools for OTRS

##Included Tools:

###Delete Tools:

* cr.DevQueueDelete:

  Delete queues from DB, also removes relations from _personal_queues_, _queue_auto_response_, _queue_perferences_ and _queue_standard_template_.

  Can delete associated tickets.

* cr.DevStateDelete:

  Delete ticket states from DB.

  Can delete associated tickets.

* cr.DevTicketDelete:

   Delete tickets from DB, including Articles and History (using OTRS API).

   Can delete all tickets at once (leaving or not initial ticket).

* cr.DevTypeDelete:

   Delete ticket types from the DB.

   Can delete associated tickets.

* cr.DevUserDelete:

  Delete users from DB, also removes relations from _group_user_, _role_user_ and **_&lt;User Preferences Table&gt;_**

  **Warning:** As many tables are related to **_&lt;User Table&gt;_** before try to delete any user it is necessary to check if is not referenced by any other table.

All tools contains a list and search options.

####Note:
This package is not intended to be use on production systems, please be aware of potensial data lost.

Use it carefully and at your own risk, data deleted by included tools might be unrecoverable!
