global without sharing class AVX_bchRatingProducer implements Database.Batchable<sObject> {

	private Boolean runNext;
    
    public AVX_bchRatingProducer(){
        this(true);
    }

    public AVX_bchRatingProducer(Boolean runNext){
        this.runNext = runNext;
	}
		
	global Database.QueryLocator start(Database.BatchableContext BC) {

		Map<String, Schema.RecordTypeInfo> mapRec = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

		Id recTypeIdProdutor = mapRec.get('Produtor').getRecordTypeId();
		
        return Database.getQueryLocator([
			SELECT TotalScore__c, TotalBilling__c
			FROM Account 
			WHERE RecordTypeId = :recTypeIdProdutor
			  AND IsActive__c = true
        ]);
	}

   	global void execute(Database.BatchableContext BC, List<Account> lsScope) {

		CalculateRating rating = new CalculateRating();

		for(Account producer :lsScope){
			producer.Rating = rating.getRating(producer);
		}

        List<Database.SaveResult> sr = Database.update(lsScope, false);
        
        for(Database.SaveResult sResult : sr){
            if(!sResult.isSuccess()) system.debug('Registros com erro: ' + sResult.Id + ' ' + sResult.getErrors());
        }
	}

	global void finish(Database.BatchableContext BC) {
        if(this.runNext) Database.executeBatch(new AVX_bchSegmentacaoGrupo(), 500);
	}
	
}