select  'RADS' DUMMY,
C.PKG_ID ITEM_CD,
C.PKG_NAME ITEM_NAME,
'' SOC_TYPE,
'' SERVICE_LEVEL,
C.PKG_PRIORITY PRIORITY,
C.BILL_CATEGORY DISCOUNT_CATEGORY,
'L' SUBSCRIBER_TYPE,
'Net' AMOUNT_TYPE,
'' REMAIN_TYPE,
'' UNLIMIT_FLAG
FROM  FY_TB_PBK_OFFER A, FY_TB_PBK_OFFER_PACKAGE B, FY_TB_PBK_PACKAGE C
WHERE A.OFFER_ID=B.OFFER_ID
AND B.PKG_ID = C.PKG_ID
AND C.PKG_TYPE='P' and C.PKG_TYPE_DTL in('AWD','ASH','APO','AWY','AWP','RDP','RDM','RVP','RVM','RAP','RAM')
AND A.PRODUCT_TYPE in ('ALL','L')
UNION
select  'RADS' DUMMY,
C.PKG_ID ITEM_CD,
C.PKG_NAME ITEM_NAME,
'' SOC_TYPE,
'' SERVICE_LEVEL,
C.PKG_PRIORITY PRIORITY,
C.BILL_CATEGORY DISCOUNT_CATEGORY,
'G' SUBSCRIBER_TYPE,
'Gross' AMOUNT_TYPE,
'' REMAIN_TYPE,
'' UNLIMIT_FLAG
FROM  FY_TB_PBK_OFFER A, FY_TB_PBK_OFFER_PACKAGE B, FY_TB_PBK_PACKAGE C
WHERE A.OFFER_ID=B.OFFER_ID
AND B.PKG_ID = C.PKG_ID
AND C.PKG_TYPE='P' and C.PKG_TYPE_DTL in('AWD','ASH','APO','AWY','AWP','RDP','RDM','RVP','RVM','RAP','RAM')
AND A.PRODUCT_TYPE <> 'L'