global without sharing class AVX_bchCalculoAdesaoHistRecebimento implements Database.Batchable<sObject> {
    
    private Boolean runNext;
    
    public AVX_bchCalculoAdesaoHistRecebimento(){
        this(true);
    }

    public AVX_bchCalculoAdesaoHistRecebimento(Boolean runNext){
        this.runNext = runNext;
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([
            SELECT 
                SumOfProductivity__c, TonVolumeDelivered__c , Harvest__r.Name, 
                PotencialValue__c   , ProductivityUnit__c   , PlantedArea__c, 
                Producer__c, //produtor
                Producer__r.ParentId //grupo
            FROM ReceiptHistory__c
            WHERE Producer__r.IsActive__c = true
              AND FRM_IsLastHarvest__c    = true
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<ReceiptHistory__c> scope){

        Map<Id, Account> mapAccountMap = this.getMapAcc(scope);
        
        Account acc = null;
        for (ReceiptHistory__c histRec : scope){

            //PRODUTOR
            if(histRec.Producer__c == null) continue;
            acc = mapAccountMap.get(histRec.Producer__c);
            if(acc == null) continue;
            this.setData(acc, histRec);

            //GRUPO
            if(histRec.Producer__r.ParentId == null) continue;
            acc = mapAccountMap.get(histRec.Producer__r.ParentId);
            if(acc == null) continue;
            this.setData(acc, histRec);
        }

        List<Database.SaveResult> sr = Database.update(mapAccountMap.values(), false);
        for(Database.SaveResult sResult : sr){
            if(!sResult.isSuccess()) system.debug('Registros com erro: ' + sResult.Id + ' ' + sResult.getErrors());
        }
    }

    private void setData(Account acc, ReceiptHistory__c histRec){
        acc.ObtainedKilos__c        += (histRec.TonVolumeDelivered__c == null) ?0 : (histRec.TonVolumeDelivered__c / 1000);
        acc.SumProductivityUnit__c  += (histRec.ProductivityUnit__c == null) ?0 :histRec.ProductivityUnit__c;
    }

    private Map<Id, Account> getMapAcc(List<ReceiptHistory__c> scope){

        Set<Id> setAccId = new Set<Id>();
        for(ReceiptHistory__c item : scope){
  
            //produtor
            if(item.Producer__c == null) continue;
            setAccId.add(item.Producer__c);

            //grupo
            if(item.Producer__r.ParentId == null) continue;
            setAccId.add(item.Producer__r.ParentId);

        }

        return new Map<Id, Account>([
            SELECT ObtainedKilos__c, SumProductivityUnit__c
            FROM Account WHERE ID IN :setAccId
             AND IsActive__c = true
        ]);
    }
    
    global void finish(Database.BatchableContext BC){
    	if(this.runNext) Database.executeBatch(new AVX_bchCalculoAdesaoFat(), 500);
    }
    
}