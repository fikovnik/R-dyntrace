-- SQLite3 schema for Rdt
create table functions (
    --[ identity ]-------------------------------------------------------------
    id integer primary key, -- equiv. to pointer of function definition SEXP
    --[ data ]-----------------------------------------------------------------
    location text,
    definition text
);

create table arguments (
    --[ identity ]-------------------------------------------------------------
    id integer primary key, -- arbitrary
    --[ data ]-----------------------------------------------------------------
    name text not null,
    position integer not null,
    --[ relations ]------------------------------------------------------------
    function_id integer not null,
    --[ keys ]-----------------------------------------------------------------
    foreign key (function_id) references functions
);

create table calls (
    --[ identity ]-------------------------------------------------------------
    id integer primary key, -- if CALL_ID is off this is equal to SEXP pointer
    pointer integer not null,
    --[ data ]-----------------------------------------------------------------
    function_name text,
    location text,
    call_type integer not null, -- 0: function, 1: built-in
    --[ relations ]------------------------------------------------------------
    function_id integer not null,
    --[ keys ]-----------------------------------------------------------------
    foreign key (function_id) references functions
);

create table promises (
    --[ identity ]-------------------------------------------------------------
    id integer primary key -- equal to promise pointer SEXP
);

create table promise_associations (
    --[ relations ]------------------------------------------------------------
    promise_id integer not null,
    call_id integer not null,
    argument_id integer not null,
    --[ keys ]-----------------------------------------------------------------
    foreign key (promise_id) references promises,
    foreign key (call_id) references calls,
    foreign key (argument_id) references arguments
);

create table promise_evaluations (
    --[ data ]-----------------------------------------------------------------
    clock integer primary key autoincrement, -- imposes an order on evaluations
    event_type integer not null, -- 0x0: lookup, 0xf: force, 0x30: peek
    --[ relations ]------------------------------------------------------------
    promise_id integer not null,
    call_id integer not null,
    --[ keys ]-----------------------------------------------------------------
    foreign key (promise_id) references promises,
    foreign key (call_id) references calls
);

create view function_evals as
select
    functions.id as function_id,
	count(*) as evaluations
from functions
left outer join calls on functions.id = calls.function_id
group by functions.id;

create view function_names as
select
    function_id,
	group_concat(distinct_name, ", ") as names
from(
    select distinct
	    functions.id as function_id,
		case
		    when calls.function_name is null then "<undefined>"
		    when calls.function_name = "" then "<undefined>"
		    else calls.function_name
		end as distinct_name
	from functions
	left outer join calls on functions.id = calls.function_id
)
group by function_id;

create view argument_evals as
select
    arguments.function_id,
    arguments.name,
    arguments.position,
    sum(case when promise_evaluations.event_type = 15 then 1 else 0 end) as forces,
    sum(case when promise_evaluations.event_type = 0 then 1 else 0 end) as lookups
from arguments
join promise_associations on arguments.id = promise_associations.argument_id
join promise_evaluations on promise_associations.promise_id = promise_evaluations.promise_id
group by arguments.id;

create view promise_evaluations_order as
select
	promise_evaluations.call_id,
	group_concat(arguments.name ||
	case
		when promise_evaluations.event_type = 0 then '=' --lookup
		when promise_evaluations.event_type = 15 then '!' -- force
		else '?' -- wildcard
	end, " < ") as events
	--group_concat(arguments.name || "@" || promise_evaluations.clock ||
	--case
	--	when promise_evaluations.event_type = 0 then '=' --lookup
	--	when promise_evaluations.event_type = 15 then '!' -- force
	--	else '?' -- wildcard
	--end, " < ") as annotated_events
from promises
join promise_evaluations on promise_associations.promise_id = promise_evaluations.promise_id
join promise_associations on promise_associations.promise_id = promises.id
join arguments on promise_associations.argument_id = arguments.id
group by promise_evaluations.call_id
order by promise_evaluations.call_id, clock;

create view function_arguments as
select
	functions.id as function_id,
	group_concat(arguments.name, ", ") as arguments
	--group_concat(arguments.name || ":" || arguments.position, ", ") as annotated_arguments
from functions
join arguments as arguments on arguments.function_id = functions.id
group by functions.id
order by functions.id, arguments.position;

-- Warning: The prepared statement generator assumes semicolons are used only to separate statements in this file,
--          If you use a semicolon for anything else in this file,
--                                                    that prepared statement generator will go explosively crazy.
--
--                                                                                         -love, the Sign Painter
