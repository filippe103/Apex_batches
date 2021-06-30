global without sharing class AVX_bchCalculoAdesaoHistCompra implements Database.Batchable<sObject> {

    private Boolean runNext;

    public AVX_bchCalculoAdesaoHistCompra(){
        this(true);
    }

    public AVX_bchCalculoAdesaoHistCompra(Boolean runNext){
        this.runNext = runNext;
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([
            SELECT InputsBillingValue__c, TotalCampaign__c, 
                   TotalValue__c,
                   AccountId__c, // acc produtor
                   AccountId__r.ParentId // acc grupo
            FROM PurchaseHistory__c
            WHERE AccountId__r.IsActive__c = true
              AND FRM_IsLastHarvest__c     = true
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<PurchaseHistory__c> scope){

        Map<Id, Account> mapAccountMap = this.getMapAcc(scope);
        Account acc = null;

        for (PurchaseHistory__c hist : scope){

            //produtor
            if(hist.AccountId__c == null) continue;
            acc = mapAccountMap.get(hist.AccountId__c);
            if(acc == null) continue;
            this.setData(acc, hist);

            //grupo
            if(hist.AccountId__r.parentId == null) continue;
            acc = mapAccountMap.get(hist.AccountId__r.parentId);
            if(acc == null) continue;
            this.setData(acc, hist);

        }

        List<Database.SaveResult> sr = Database.update(mapAccountMap.values(), false);  
        
        for(Database.SaveResult sResult : sr){
            if(!sResult.isSuccess()) system.debug('Registros com erro: ' + sResult.Id + ' ' + sResult.getErrors());
        }

    }

    private Map<Id, Account> getMapAcc(List<PurchaseHistory__c> scope){
        Set<Id> setAccId = new Set<Id>();

        for(PurchaseHistory__c hist : scope){
            //produtor
            if(hist.AccountId__c == null) continue;
            setAccId.add(hist.AccountId__c);

            //grupo
            if(hist.AccountId__r.ParentId == null) continue;
            setAccId.add(hist.AccountId__r.ParentId);
        }

        return new Map<Id, Account>([
            SELECT InputsBillingValue__c, CampainTotal__c, FATTotal__c
            FROM Account 
            WHERE ID IN :setAccId
            AND IsActive__c = true
        ]);
    }

    private void setData(Account acc, PurchaseHistory__c hist){
        acc.InputsBillingValue__c += hist.InputsBillingValue__c; 
        acc.CampainTotal__c       += hist.TotalCampaign__c;
        acc.FATTotal__c           += hist.TotalValue__c;
    }
    
    global void finish(Database.BatchableContext BC){
    	if(this.runNext) Database.executeBatch(new AVX_bchCalculoAdesaoHistRecebimento(), 500);
    }
    
}