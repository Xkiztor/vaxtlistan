create or replace function prevent_disallowed_updates()
returns trigger as $$
begin
  -- Only allow changing "status"
  if (new.name <> old.name or new.sv_name <> old.sv_name or new.id <> old.id) then
    raise exception 'You are only allowed to update status';
  end if;

  return new;
end;
$$ language plpgsql;

create trigger check_updates
before update on facit
for each row
execute function prevent_disallowed_updates();
