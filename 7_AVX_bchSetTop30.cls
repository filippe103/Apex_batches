/*******************************************************************************
Desenvolvido por: Avanxo Brasil
Autor: Edson de Assis Dalécio
Projeto: Cocamar CRM
Descrição: Batch responsável por setar quem é top 30.
Mudanças (Versões)
-------------------------------------
No. 	  Data 				 Autor 			  Descrição
------ ---------- -------------------------- ----------------------------
1.0    30-05-2019  Edson de Assis Dalécio	  Versão inicial.	

*******************************************************************************/
global without sharing class AVX_bchSetTop30 implements Database.Batchable<sObject>, Database.Stateful {

    private Id recordTypeId;

    global AVX_bchSetTop30(Id recordTypeId){
        this.recordTypeId = recordTypeId;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id,
                (
                    SELECT TotalBilling__c
                    FROM Contas__r 
                    WHERE RecordTypeId = :recordTypeId
                      AND isActive__c  = true
                    ORDER BY TotalBilling__c 
                    DESC LIMIT 30
                )
            FROM Unit__c WHERE Active__c = true
        ]);
	}

    global void execute(Database.BatchableContext BC, List<Unit__c> scope) {

        List<Account> lsAcc = new List<Account>();
        
        for(Unit__c un : scope){
            for(Account acc : un.Contas__r){
                lsAcc.add(new Account(Id = acc.Id, ScoreTop30__c = 15));
            }
        }
        
        List<Database.SaveResult> sr = Database.update(lsAcc, false);
        
        for(Database.SaveResult sResult : sr){
            if(!sResult.isSuccess()) system.debug('Registros com erro: ' + sResult.Id + ' ' + sResult.getErrors());
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
}