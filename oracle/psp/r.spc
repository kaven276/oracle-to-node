create or replace package r is

	ct_http   constant pls_integer := 0;
	ct_nodejs constant pls_integer := 1;

	na pv.vc_arr;
	va pv.vc_arr;

	procedure "_init"
	(
		c        in out nocopy utl_tcp.connection,
		passport pls_integer
	);

	procedure after_map;

	procedure getblob
	(
		p_len  in pls_integer,
		p_blob in out nocopy blob
	);

	procedure body2clob;
	procedure body2nclob;
	procedure body2auto;

	procedure read_line_init(nl varchar2 := null);
	procedure read_line(line in out nocopy varchar2);
	procedure read_nline(line in out nocopy nvarchar2);
	function read_line_no_more return boolean;

	function call_type return varchar2;
	function method return varchar2;
	function protocol return varchar2;
	function sdns return varchar2;
	function pdns return varchar2;
	function hostname return varchar2;
	function port return pls_integer;
	function host return varchar2;

	function prog return varchar2;
	function pack return varchar2;
	function proc return varchar2;
	function type return varchar2;

	function gid return varchar2;
	function site return varchar2;
	function url return varchar2;
	function dir return varchar2;
	function pathname return varchar2;
	function subpath return varchar2;
	function qstr return varchar2;
	function url_full return varchar2;
	function dir_full return varchar2;

	function nc return varchar2;
	function nd return date;
	function nn return number;

	procedure req_charset(cs varchar2);
	procedure req_charset_db;
	procedure req_charset_ndb;
	procedure req_charset_utf8;

	function is_null(name varchar2) return boolean;

	procedure setc
	(
		name  varchar2,
		value varchar2
	);

	procedure getc
	(
		name   varchar2,
		value  in out nocopy varchar2 character set any_cs,
		defval varchar2
	);

	procedure getc
	(
		name  varchar2,
		value in out nocopy varchar2 character set any_cs
	);

	procedure getn
	(
		name   varchar2,
		value  in out nocopy number,
		defval number,
		format varchar2 := null
	);

	procedure getn
	(
		name   varchar2,
		value  in out nocopy number,
		format varchar2 := null
	);

	procedure getd
	(
		name   varchar2,
		value  in out nocopy date,
		defval date,
		format varchar2 := null
	);

	procedure getd
	(
		name   varchar2,
		value  in out nocopy date,
		format varchar2 := null
	);

	function getc
	(
		name   varchar2,
		defval nvarchar2
	) return nvarchar2;

	function getc(name varchar2) return nvarchar2;

	function getn
	(
		name   varchar2,
		defval number,
		format varchar2 := null
	) return number;

	function getn
	(
		name   varchar2,
		format varchar2 := null
	) return number;

	function getd
	(
		name   varchar2,
		defval date,
		format varchar2 := null
	) return date;

	function getd
	(
		name   varchar2,
		format varchar2 := null
	) return date;

	procedure gets
	(
		name  varchar2,
		value in out nocopy st
	);
	function gets(name varchar2) return st;
	function unescape(value varchar2) return varchar2;

	function s(name varchar2) return varchar2;
	procedure s
	(
		name  varchar2,
		value varchar2
	);
	function lat return date;
	function session(name varchar2) return varchar2;
	procedure session
	(
		name  varchar2,
		value varchar2
	);

	function header(name varchar2) return varchar2;

	function user return varchar2;
	function pass return varchar2;

	function cookie(name varchar2) return varchar2;

	function msid return varchar2;
	function bsid return varchar2;

	function dbu return varchar2;
	function file return varchar2;

	function etag return varchar2;
	function lmt return date;
	function referer return varchar2;
	function referer2 return varchar2;
	function ua return varchar2;

	function client_addr return varchar2;
	function client_port return pls_integer;
	function server_family return varchar2;
	function server_addr return varchar2;
	function server_port return pls_integer;

end r;
/
