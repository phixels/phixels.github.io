column xxtmp new_value xx_file_naam noprint
select 'xxsku_pagl_'||instance_name||'_invoice_id_' || '&1' xxtmp from v$instance
/
alter session set NLS_DATE_FORMAT='YYYY/MM/DD HH24:MI';
set linesize 140

col diff_acc              FORMAT 999g999g900d99  HEADING "Versch.acc"
col diff_ent              FORMAT 999g999g900d99  HEADING "Versch.ent."
col segments              FORMAT a55             HEADING "Rekening"
col post                  FORMAT a3              HEADING "GL"
col invoice_num           FORMAT a30             HEADING "Fact.nr."
col validation_request_id FORMAT 999             HEADING "Vri"
col doc_sequence_value                           HEADING "Boekst.nr."

spool &xx_file_naam

compute sum label 'Totaal:' of diff_acc diff_ent on report
break on report

select invoice_id, invoice_num, doc_sequence_value, validation_request_id
, to_char(last_update_date, 'YYYY/MM/DD') lupd
, substr(AP_INVOICES_PKG.GET_APPROVAL_STATUS( INVOICE_ID,INVOICE_AMOUNT,PAYMENT_STATUS_FLAG,INVOICE_TYPE_LOOKUP_CODE),1,10) apprv_stat
,AP_INVOICES_PKG.GET_POSTING_STATUS( INVOICE_ID) post, inv.amount_paid
--, total_tax_amount , validated_tax_amount
from ap_invoices_all inv
where invoice_id =&1
/

select code_combination_id cc_id--ae_header_id,
,      sum(nvl(xln.accounted_dr,0)-nvl(xln.accounted_cr,0)) diff_acc
,      sum(nvl(xln.entered_dr,0)-nvl(xln.entered_cr,0)) diff_ent
, ( select segment1||'.'||segment2||'.'||segment3||'.'||segment4||'.'||segment5||'.'
        || segment6||'.'||segment7||'.'||segment8||'.'||segment9
    from gl_code_combinations cc where cc.code_combination_id = xln.code_combination_id) segments
--,      sum(nvl(xln.accounted_dr,0)) sum_acc_dr,      sum(nvl(xln.accounted_cr,0)) sum_acc_cr
--,      sum(nvl(xln.entered_dr,0)) sum_ent_dr,        sum(nvl(xln.entered_cr,0)) sum_ent_cr
from xla_ae_lines xln
where xln.ae_header_id in
( --4700086,7863921
    select ae_header_id
    from xla_ae_headers
    where event_id in
    ( select event_id
      from xla_events
      where entity_id =
      (select entity_id
      from xla.xla_transaction_ENTITIES xta
      where xta.source_id_int_1 = &1
      and entity_code = 'AP_INVOICES')))
group by code_combination_id--,ae_header_id
order by 4
/

col post              FORMAT A3
col bedrag            FORMAT 999g999g900d99  HEADING "Bedrag"
col accounting_date                          HEADING "Acc.Datum" 

select 
  lpad(invd.invoice_line_number,2,' ') ||'|'|| lpad(invd.distribution_line_number,2,' ') ln_ds
, invd.amount bedrag
, invd.posted_flag post
, invd.reversal_flag rev
, segment1||'.'||segment2||'.'||segment3||'.'||
  segment4||'.'||segment5||'.'||segment6||'.'||
  segment7||'.'||segment8||'.'||segment9 segments
, invd.line_type_lookup_code
, to_char(invd.accounting_date, 'YYYY/MM/DD') accounting_date 
, invd.accounting_event_id
from ap_invoice_distributions_all invd
,    gl_code_combinations cc
where invd.invoice_id = &1
and   invd.dist_code_combination_id = cc.code_combination_id
order by invd.invoice_line_number, invd.distribution_line_number
/
spool off
