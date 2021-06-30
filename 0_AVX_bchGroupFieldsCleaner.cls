/*******************************************************************************
Desenvolvido por: Avanxo Brasil
Autor: Edson de Assis Dalécio
Projeto: Cocamar CRM
Descrição: Batch responsável por limpar os campos da segmentação.
Mudanças (Versões)
-------------------------------------
No. 	  Data 				 Autor 			  Descrição
------ ---------- -------------------------- ----------------------------
1.0    12-08-2019  Edson de Assis Dalécio	  Versão inicial.	

*******************************************************************************/
global without sharing class AVX_bchGroupFieldsCleaner implements Database.Batchable<sObject>, Queueable{

    private Boolean runNext;
    private Set<ID> setQueueAccId;

    public AVX_bchGroupFieldsCleaner(){
        this(true);
    }

    public AVX_bchGroupFieldsCleaner(Boolean runNext){
        this.runNext = runNext;
    }

    public AVX_bchGroupFieldsCleaner(Set<ID> setQueueAccId){
        this.setQueueAccId = setQueueAccId;
    }

	global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([
            SELECT FRM_BondScore__c FROM Account
        ]);
    }
    
    //Queueable execute 
    global void execute(QueueableContext context) {
        this.clearData([SELECT FRM_BondScore__c FROM Account WHERE ID IN :this.setQueueAccId]);
    }

    global void execute(Database.BatchableContext BC, List<Account> scope){
        if(this.runNext) this.clearData(scope);
        //cria uma fila async
        if(!this.runNext) System.enqueueJob(new AVX_bchGroupFieldsCleaner(new Map<Id, Account>(scope).keySet()));
    }
    
    private void clearData( List<Account> scope ){

        for(Account acc : scope){
            acc.Rating              = 'D2';
            //campos somandos no batch AVX_bchPlantedAreaForGroup
            acc.InputsPotencialValue__c     = 0; //Valor Potencial Insumos Produtor
            acc.SumPlantedArea__c           = 0; //Total Área (ha) Produtor
            acc.ProductivitySum__c          = 0; //	Produtividade Obtida Produtor
            acc.CountHarvest__c             = 0; //	Contador de Safras
            acc.ReceiptPotential__c         = 0; //	Potencial Entrega Produtor
            acc.SumTotalProductivityUnit__c = 0; // Produtividade da unidade -> UnitProductivityIndex__c 
            acc.SumTotalAreaUnit__c         = 0; // Area da unidade -> UnitProductivityIndex__c 
            // acc.PotentialReceiptsValueTotal__c = 0; CAMPO INATIVADO
            //campos do historico de compra AVX_bchCalculoAdesaoHistCompra
            acc.InputsBillingValue__c = 0; // Valor Faturado Insumos Produtor
            acc.FATTotal__c           = 0; // Valor Total Faturado Produtor
            acc.CampainTotal__c       = 0; // Valor Faturado Campanha(s) Produtor
            //campos historico de recebimento AVX_bchCalculoAdesaoHistRecebimento
            acc.ObtainedKilos__c       = 0; //Produtos Entregues Produtor (ton)
            acc.SumProductivityUnit__c = 0; //Produtividade Obtida Unidade
            //campos do historico de compra AVX_bchCalculoAdesaoFat
            acc.AverageBilling__c                  = 0; //Média/Ano Faturamento Produtor Bruto
            acc.AverageBillingCommercialization__c = 0; //Média/Ano Comercialização de Grãos Bruto
            // top 15 por unidade unidade AVX_bchSetTop30
            acc.ScoreTop30__c          = 0;
            //campos somados no batch 
            acc.SumPlantingAreaProd__c = 0;
            
            //define o valor padrão para o registro apartir da formula
            acc.BondScore__c = acc.FRM_BondScore__c;

            //campos inativados
            // acc.SumPlantedArea2__c  = 0;
            // acc.PotentialValuesOfPurchasesTotal__c = 0; 
        }
        List<Database.SaveResult> sr = Database.update(scope, false);
        
        for(Database.SaveResult sResult : sr){
            if(!sResult.isSuccess()) System.debug(LoggingLevel.ERROR, 'Registros com erro: ' + sResult.Id + ' ' + sResult.getErrors());
        }
    }

    global void finish(Database.BatchableContext BC){
        if(this.runNext) Database.executeBatch(new AVX_bchPlantedAreaForGroup(), 500);
    }
}