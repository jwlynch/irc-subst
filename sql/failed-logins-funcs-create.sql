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
      select now() into cd;
    else
      cd := creation_date;
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

-- the pg lib doesn't have this func, got it from https://wiki.postgresql.org/wiki/Array_reverse

CREATE OR REPLACE FUNCTION array_reverse(anyarray)
RETURNS anyarray
AS
$$
SELECT ARRAY(
    SELECT $1[i]
        FROM generate_subscripts($1,1) AS s(i)
	    ORDER BY i DESC
	    );
$$
LANGUAGE 'sql'
STRICT IMMUTABLE;

create or replace function hostname_split
(
  hostname text
)
returns text []
language 'plpgsql'
as
$$
  declare
    res text[];
  begin
    res = regexp_split_to_array(hostname, '\.');

    return res;
  end;
$$;

create or replace function reverse_hostname(hostname text)
returns text
language 'plpgsql'
as
$$
  begin
    return array_to_string(array_reverse(hostname_split(hostname)), '.');
  end;
$$;

