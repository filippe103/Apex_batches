/*******************************************************************************
Desenvolvido por: Avanxo Brasil
Autor: Edson de Assis Dalécio
Projeto: Cocamar CRM
Descrição: Batch responsável por atribuir os valores de segmentação de produtor que serão 
		   utilizados para o grupo.
Mudanças (Versões)
-------------------------------------
No. 	  Data 				 Autor 			  Descrição
------ ---------- -------------------------- ----------------------------
1.0    12-08-2019  Edson de Assis Dalécio	  Versão inicial.	

*******************************************************************************/
global without sharing class AVX_bchPlantedAreaForGroup implements Database.Batchable<sObject>{
    
    private Boolean runNext;
    
    public AVX_bchPlantedAreaForGroup(){
        this(true);
    }

    public AVX_bchPlantedAreaForGroup(Boolean runNext){
        this.runNext = runNext;
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([
            SELECT  Hectares__c, 
                    FRM_PotentialInputs__c,
                    FRM_ProductivityPotencialValue__c,
                    FRM_ProductivityObtainedProducer__c, //unidade produtor
                    FRM_UnitHarvestCulture_Produtor__c, //unidade grupo
                    FRM_UnitHarvestCulture_Grupo__c,
                    Property__c, //acc propriedade
                    Property__r.ParentId, // acc produtor
                    Property__r.Parent.IsActive__c, // acc produtor ativo
                    Property__r.Parent.ParentId, // acc grupo
                    Property__r.Parent.Parent.IsActive__c, // acc grupo ativo
                    HarvestCulture__r.Harvest__c //SAFRA
            FROM PlantedArea__c 
            WHERE HarvestCulture__c       != null 
              AND FRM_IsLastHarvest__c    = true
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<PlantedArea__c> scope){
        
        //sumariza a area plantada na conta
        Map<Id, Account> mapAccountMap = this.getAccByPlantedArea(scope);
        
        //atribui a contagem de safra na conta
        this.setHarvestInAcc(mapAccountMap);

        //atribui a produtividade na conta
        this.setUnitProductivity(scope, mapAccountMap);
                
        List<Database.SaveResult> sr = Database.update(mapAccountMap.values(), false);  
        for(Database.SaveResult sResult : sr){
            if(!sResult.isSuccess()) System.debug(LoggingLevel.ERROR, 'Registros com erro: ' + sResult.Id + ' ' + sResult.getErrors());
        }
    }

    private Map<Id, Account> getAccByPlantedArea(List<PlantedArea__c> scope){

        Map<Id, Account> mapAccountMap = this.getMapAcc(scope);
        
        for(PlantedArea__c pa : scope){
           
            //soma por propriedade
            this.setData(
                mapAccountMap.get(pa.Property__c), 
                pa
            );

            //soma por produtor
            if(pa.Property__r.ParentId == null) continue;
            this.setData(
                mapAccountMap.get(pa.Property__r.ParentId), 
                pa
            );

            //soma por grupo
            if(pa.Property__r.Parent.ParentId == null) continue;
            this.setData(
                mapAccountMap.get(pa.Property__r.Parent.ParentId), 
                pa
            );
        }

        return mapAccountMap;
    }

    private Map<Id, Account> getMapAcc(List<PlantedArea__c> scope){

        Set<Id> setAccId = new Set<Id>();
        for(PlantedArea__c pa : scope){
            
            //propryedade todas ativas e inativas
            setAccId.add(pa.Property__c);

            //produtor somente os ativos
            if(pa.Property__r.ParentId == null) continue;
            if(pa.Property__r.Parent.IsActive__c) setAccId.add(pa.Property__r.ParentId);

            //grupo somente os ativos
            if(pa.Property__r.Parent.ParentId == null) continue;
            if(pa.Property__r.Parent.Parent.IsActive__c) setAccId.add(pa.Property__r.Parent.ParentId);

        }

        return new Map<Id, Account>([
            SELECT InputsPotencialValue__c ,ReceiptPotential__c,
                   SumPlantedArea__c       ,ProductivitySum__c,
                   CountHarvest__c         ,SumTotalProductivityUnit__c,
                   SumTotalAreaUnit__c     ,RecordTypeId
            FROM Account 
            WHERE ID IN :setAccId
        ]);
    }

    private void setData(Account acc, PlantedArea__c pa){

        if(acc == null) return;

        acc.InputsPotencialValue__c += pa.FRM_PotentialInputs__c;
        acc.ReceiptPotential__c     += pa.FRM_ProductivityPotencialValue__c;
        acc.SumPlantedArea__c       += (pa.Hectares__c == null) ?0 :pa.Hectares__c;
        acc.ProductivitySum__c      += pa.FRM_ProductivityObtainedProducer__c;
    }

    private Map<Id, Account> filterAccount(Map<Id, Account> mapAcc, Id recodTypeId){
        Map<Id, Account> result = new Map<Id, Account>();
        if(recodTypeId == null) return result;
        
        for(Account acc :mapAcc.values()){
            if(acc.recordTypeId == recodTypeId) result.put(acc.Id, acc);
        }

        return result;
    }

    private void setHarvestInAcc(Map<Id, Account> mapAccountMap){

        Map<String, Schema.RecordTypeInfo> mapRec = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        Id recTypeId = null;

        //Propriedade
        recTypeId = mapRec.get('Propriedade').getRecordTypeId();
        this.setHarvestCount(
            this.filterAccount(mapAccountMap, recTypeId), 
            'Property__c'
        );

        //produtor
        recTypeId = mapRec.get('Produtor').getRecordTypeId();
        this.setHarvestCount(
            this.filterAccount(mapAccountMap, recTypeId), 
            'Property__r.ParentId'
        );

        //grupo
        recTypeId = mapRec.get('Grupo').getRecordTypeId();
        this.setHarvestCount(
            this.filterAccount(mapAccountMap, recTypeId), 
            'Property__r.Parent.ParentId'
        );
    }

    private void setHarvestCount(Map<Id, Account> mapAcc, String fieldGroupBy){

        if(mapAcc.isEmpty()) return;

        Set<Id> setAccId = mapAcc.keySet();
        String strSoql = 'SELECT {0} acc,  HarvestCulture__r.Harvest__r.name , count(id)' 
                       + ' FROM PlantedArea__c WHERE Harvest__c <> NULL'
                       + ' AND {0} IN :setAccId AND FRM_IsLastHarvest__c = true'
                       + ' GROUP BY {0}, HarvestCulture__r.Harvest__r.name';
        
        AggregateResult[] lsResult = (AggregateResult[])Database.query(String.format(strSoql, new String[]{fieldGroupBy}));

        Map<Id, Decimal> mapAccCountHarvest = new Map<Id, Decimal>();

        //conta as safras
        for(AggregateResult rs :lsResult) {

            Id accId = (Id)rs.get('ACC');

            Decimal qtde = mapAccCountHarvest.get(accId);

            if(qtde == null) qtde = 0;
            qtde ++;

            mapAccCountHarvest.put(accId, qtde);
        }

        //atualiza a conta
        for(Id accId : mapAcc.keySet()){
            Decimal qtde = mapAccCountHarvest.get(accId);

            if(qtde == null) continue;

            Account acc = mapAcc.get(accId);
            acc.CountHarvest__c = qtde;
        }
    }
    
    private void setUnitProductivity(List<PlantedArea__c> scope, Map<Id, Account> mapAcc){
        
        Map<Id, TotalIndex> mapUnitProductivityIndex = this.getUnitProductivityByAcc(scope);

        for(Id accId :mapAcc.keySet()){

            TotalIndex tIdx = mapUnitProductivityIndex.get(accId);
            if(tIdx == null) continue;

            Account acc = mapAcc.get(accId);
            acc.SumTotalProductivityUnit__c = tIdx.TotalProductivity;
            acc.SumTotalAreaUnit__c         = tIdx.TotalArea;
        }
    }

    private  Map<Id, TotalIndex> getUnitProductivityByAcc(List<PlantedArea__c> scope){

        Set<String>          setKey                   = new Set<String>();
        Map<Id, Set<String>> mapAccUnitHarvestCulture = new Map<Id, Set<String>>();
        
        for(PlantedArea__c pa : scope){
            setKey.add(pa.FRM_UnitHarvestCulture_Produtor__c);
            setKey.add(pa.FRM_UnitHarvestCulture_Grupo__c);
            
            Set<String> keySet = null;
            //produtor
            keySet = mapAccUnitHarvestCulture.get(pa.Property__r.ParentId);
            if(keySet == null) keySet = new Set<String>();
            keySet.add(pa.FRM_UnitHarvestCulture_Produtor__c);
            mapAccUnitHarvestCulture.put(pa.Property__r.ParentId, keySet);
            
            //grupo
            keySet = mapAccUnitHarvestCulture.get(pa.Property__r.Parent.ParentId);
            if(keySet == null) keySet = new Set<String>();
            keySet.add(pa.FRM_UnitHarvestCulture_Grupo__c);
            mapAccUnitHarvestCulture.put(pa.Property__r.Parent.ParentId, keySet);
        }

        Map<String, UnitProductivityIndex__c> mapUnitProductivityIndex = new Map<String, UnitProductivityIndex__c>();
        for(UnitProductivityIndex__c un : [
            SELECT  ExternalId__c ,
                    Area__c       ,TotalProductivity__c 
            FROM UnitProductivityIndex__c
            WHERE ExternalId__c IN :setKey
        ]){
            mapUnitProductivityIndex.put(un.ExternalId__c, un);
        }

        Map<Id, TotalIndex> mapIndexByAcc = new Map<Id, TotalIndex>();
        for(Id accId :mapAccUnitHarvestCulture.keySet()){

            TotalIndex totIdx = mapIndexByAcc.get(accId);
            if(totIdx == null) totIdx = new TotalIndex();
            mapIndexByAcc.put(accId, totIdx);

            Set<String> setAccIndexKey = mapAccUnitHarvestCulture.get(accId);
            if(setAccIndexKey.isEmpty()) continue;

            for(String idxKey : setAccIndexKey){
                UnitProductivityIndex__c unProdIdx = mapUnitProductivityIndex.get(idxKey);
                if(unProdIdx == null) continue;
                totIdx.addUnitProductivityIndex(unProdIdx);
            }
        }

        return mapIndexByAcc;
    }

    global void finish(Database.BatchableContext BC){
        if(this.runNext) Database.executeBatch(new AVX_bchCalculoAdesaoHistCompra(), 500);
    }

/* ******************************************************************************************** */

    private class TotalIndex {
        public Decimal TotalProductivity {get; set;}
        public Decimal TotalArea         {get; set;}

        private TotalIndex(){
            this.TotalProductivity = 0;
            this.TotalArea         = 0;
        }

        public void addUnitProductivityIndex(UnitProductivityIndex__c idx){
            this.TotalProductivity += idx.TotalProductivity__c;
            this.TotalArea         += idx.Area__c;
        }
    }
}