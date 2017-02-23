drop function reverse_hostname(text);

drop function failed_login_new
(
  failed_login_id int8,
  host_or_ip text,
  creation_date timestamp with time zone
);

