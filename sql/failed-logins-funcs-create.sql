create or replace function failed_login_new
(
  failed_login_id int8 default null,
  host_or_ip text default null,
  creation_date timestamp with time zone default null
)
returns int8
language 'plpgsql'
as
$$
  declare
    fl_id int8;
    hoi text;
    cd timestamp with time zone;
  begin
    if failed_login_id is null then
      select nextval('object_id_seq') into fl_id;
    else
      fl_id := failed_login_id;
    end if;

    hoi := host_or_ip;

    if creation_date is null then
    else
    end if;

    insert into
      failed_logins_sasl
      (
        failed_login_id,
	host_or_ip_addr,
	timestamp
      )
      values
      (
        fl_id,
        hoi,
        cd
      );

    return fl_id;
  end;
$$;
