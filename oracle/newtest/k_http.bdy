create or replace package body k_http is

	procedure status_line(code pls_integer := 200) is
	begin
		pv.status_code := code;
	end;

	procedure header
	(
		name  varchar2,
		value varchar2
	) is
	begin
		e.chk(lower(name) in ('content-type', 'content-encoding', 'content-length', 'transfer-encoding'),
					-20004,
					'You must use the specific API instead of the general h.header API to set the http header field');
		pv.headers(name) := value;
	end;

	procedure content_type
	(
		mime_type varchar2 := 'text/html',
		charset   varchar2 := 'UTF-8'
	) is
	begin
		e.chk(lower(charset) = 'utf8', -20002, 'IANA charset should be utf-8, not utf8');
		e.chk(r.type = 'c', -20005, '_c layer should not have entity content, so should not set content-type');
		pv.mime_type := mime_type;
		pv.charset   := lower(charset);
		-- utl_i18n.generic_context, utl_i18n.iana_to_oracle
		pv.charset_ora := utl_i18n.map_charset(charset, 0, 1);
		pv.headers('Content-Type') := mime_type || '; charset=' || charset;
		pv.allow_content := true;
		-- r.unescape_parameters;
	end;

	procedure content_encoding_gzip is
	begin
		pv.headers('Content-Encoding') := 'gzip';
		pv.gzip := true;
	end;

	procedure content_encoding_identity is
	begin
		pv.headers('Content-Encoding') := 'identity';
		pv.gzip := false;
	end;

	procedure content_encoding_auto is
	begin
		pv.headers.delete('Content-Encoding');
		pv.gzip := null;
	end;

	procedure location(url varchar2) is
	begin
		-- [todo] absolute URI
		pv.headers('Location') := utl_url.escape(url, false, pv.charset_ora);
	end;

	procedure transfer_encoding_chunked is
	begin
		pv.headers('Transfer-Encoding') := 'chunked';
		pv.use_stream := true;
	end;

	procedure transfer_encoding_identity is
	begin
		pv.headers('Transfer-Encoding') := 'identity';
		pv.use_stream := false;
	end;

	procedure transfer_encoding_auto is
	begin
		pv.headers.delete('Transfer-Encoding');
		pv.use_stream := false; -- default to not use_stream
	end;

	procedure write_head is
		v  varchar2(4000);
		nl varchar2(2) := chr(13) || chr(10);
		l  pls_integer;
		n  varchar2(30);
	begin
		if pv.header_writen then
			return;
		else
			pv.header_writen := true;
		end if;
	
		begin
			if pv.headers('Transfer-Encoding') = 'chunked' then
				pv.headers.delete('Content-Length');
			end if;
		exception
			when no_data_found then
				null;
		end;
	
		v := pv.status_code || nl;
		n := pv.headers.first;
		while n is not null loop
			v := v || n || ': ' || pv.headers(n) || nl;
			n := pv.headers.next(n);
		end loop;
		l := utl_tcp.write_text(pv.c, to_char(lengthb(v), '0000') || v);
	end;

	procedure http_header_close is
	begin
		if pv.use_stream then
			write_head;
		end if;
	
		if not pv.allow_content then
			null; -- go out, cease execution
		end if;
	
		pv.buffered_length := 0;
	
		if pv.use_stream and pv.gzip then
			pv.gzip_handle := utl_compress.lz_compress_open(pv.gzip_entity, 1);
			pv.gzip_amount := 0;
		end if;
	end;

	procedure go
	(
		url    varchar2,
		status number := null -- maybe 302(_b),303(_c feedback),201(_c new)
	) is
	begin
		status_line(nvl(status, case r.type when 'c' then 303 else 302 end));
		location(url);
		write_head;
	end;

end k_http;
/
