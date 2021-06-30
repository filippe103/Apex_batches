/*******************************************************************************
Desenvolvido por: Avanxo Brasil
Autor: Edson de Assis Dalécio
Projeto: Cocamar CRM
Descrição: Batch responsável por atribuir os valores de segmentação do grupo.
Mudanças (Versões)
-------------------------------------
No. 	  Data 				 Autor 			  Descrição
------ ---------- -------------------------- ----------------------------
1.0    12-08-2019  Edson de Assis Dalécio	  Versão inicial.	

*******************************************************************************/

global without sharing class AVX_bchSegmentacaoGrupo implements Database.Batchable<sObject>{
    
    private Boolean runNext;
    
    public AVX_bchSegmentacaoGrupo(){
        this(true);
    }

    public AVX_bchSegmentacaoGrupo(Boolean runNext){
        this.runNext = runNext;
    }

	global Database.QueryLocator start(Database.BatchableContext BC){

        Map<String, Schema.RecordTypeInfo> mapRec = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

        Id recTypeIdGroup    = mapRec.get('Grupo').getRecordTypeId();
        Id recTypeIdProdutor = mapRec.get('Produtor').getRecordTypeId();

        return Database.getQueryLocator([
            SELECT TotalScore__c, TotalBilling__c, 
                (
                    SELECT BondScore__c
                    FROM ChildAccounts 
                    WHERE RecordTypeId = :recTypeIdProdutor
                      AND IsActive__c = true
                    ORDER BY BondScore__c DESC LIMIT 1
                )        
            FROM Account WHERE RecordTypeId = :recTypeIdGroup
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<Account> scope){
        
        CalculateRating rating = new CalculateRating();

        for(Account grupo : scope){

            //calcula o rating do grupo
            grupo.Rating = rating.getRating(grupo);

            //maior score do produtor será atribuido para o grupo
            if(grupo.ChildAccounts.isEmpty()) continue;
            grupo.BondScore__c = grupo.ChildAccounts.get(0).BondScore__c;
        }

        List<Database.SaveResult> sr = Database.update(scope, false);
        
        for(Database.SaveResult sResult : sr){
            if(!sResult.isSuccess()) system.debug('Registros com erro: ' + sResult.Id + ' ' + sResult.getErrors());
        }
    }
    
    global void finish(Database.BatchableContext BC){

        Map<String, Schema.RecordTypeInfo> mapRec = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

        Id recTypeIdGroup    = mapRec.get('Grupo').getRecordTypeId();
        Id recTypeIdProdutor = mapRec.get('Produtor').getRecordTypeId();

 		if(this.runNext) Database.executeBatch(new AVX_bchSetTop30(recTypeIdGroup), 50);
 		if(this.runNext) Database.executeBatch(new AVX_bchSetTop30(recTypeIdProdutor), 50);
    }
}