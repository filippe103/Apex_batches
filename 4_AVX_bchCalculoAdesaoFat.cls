global without sharing class AVX_bchCalculoAdesaoFat implements Database.Batchable<sObject> {

    private Boolean runNext;
    
    public AVX_bchCalculoAdesaoFat(){
        this(true);
    }

    public AVX_bchCalculoAdesaoFat(Boolean runNext){
        this.runNext = runNext;
    }

	global Database.QueryLocator start(Database.BatchableContext BC){
    	return Database.getQueryLocator([
            SELECT  Value__c, Producer__c, 
                    RecordTypeId,
                    Producer__r.ParentId,
                    RecordType.DeveloperName
             FROM Billing__c
            WHERE FRM_IsLastHarvest__c    = true
              AND Producer__r.isActive__c = true
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<Billing__c> scope){

        Map<Id, Account> mapAccountMap = this.getMapAcc(scope);
        Account acc = null;

        for(Billing__c billing : scope){

             //produtor
            if(billing.Producer__c == null) continue;
            this.setData(
                mapAccountMap.get(billing.Producer__c), 
                billing
            );
 
             //grupo
            if(billing.Producer__r.ParentId == null) continue;
            this.setData(
                mapAccountMap.get(billing.Producer__r.ParentId), 
                billing
            );
        }

        List<Database.SaveResult> sr = Database.update(mapAccountMap.values(), false);  
        
        for(Database.SaveResult sResult : sr){
            if(!sResult.isSuccess()) System.debug(LoggingLevel.ERROR, 'Registros com erro: ' + sResult.Id + ' ' + sResult.getErrors());
        }
    }

    private Map<Id, Account> getMapAcc(List<Billing__c> scope){

        Set<Id> setAccId = new Set<Id>();
        for(Billing__c item : scope){

            //produtor
            if(item.Producer__c == null) continue;
            setAccId.add(item.Producer__c);

            //grupo
            if(item.Producer__r.ParentId == null) continue;
            setAccId.add(item.Producer__r.ParentId);

        }

        return new Map<Id, Account>([
            SELECT  AverageBilling__c,
                    AverageBillingCommercialization__c
            FROM Account 
            WHERE ID IN :setAccId
            AND IsActive__c = true
        ]);
    }

    private void setData(Account acc, Billing__c billing){

        if(acc == null || billing.RecordTypeId == null) return;

        Decimal val = billing.Value__c;
        if(val == null) val = 0;

        switch on billing.RecordType.DeveloperName {
            when 'FIXADO' {
                acc.AverageBillingCommercialization__c += val;
            }
            when 'COMPRA' {
                acc.AverageBilling__c += val;
            }
        }
    }
    
    global void finish(Database.BatchableContext BC){
        if(this.runNext) Database.executeBatch(new AVX_bchRatingProducer(), 500);
    }
    
}