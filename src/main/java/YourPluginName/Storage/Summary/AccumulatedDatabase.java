package YourPluginName.Storage.Summary;

import YourPluginName.Storage.GeneralDataTools;

import java.util.concurrent.CompletableFuture;

public class AccumulatedDatabase implements GeneralDataTools<AccumulatedData, AccumulatedData> {

    @Override
    public boolean setup() {
        return false;
    }

    @Override
    public CompletableFuture<AccumulatedData> getData() {
        return null;
    }

    @Override
    public void update(AccumulatedData data) {

    }
}
