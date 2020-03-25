package YourPluginName.Storage.Summary;
import YourPluginName.Storage.KeyValuePair;
import org.bukkit.configuration.serialization.ConfigurationSerializable;
import org.bukkit.configuration.serialization.SerializableAs;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.function.Predicate;

@SerializableAs("AccumulatedData")
public class AccumulatedData implements ConfigurationSerializable, KeyValuePair<UUID, AccumulatedData> {

    private long lastStartTime;
    private boolean active;

    private UUID uuid;
    private long total;
    private long starts;
    private long firstLoginTimeStamp;
    private long averageTime;

    public void start() {
        this.starts++;
        this.active = true;
        this.lastStartTime = System.currentTimeMillis();
        if (this.starts == 1)
            this.firstLoginTimeStamp = this.lastStartTime;
    }

    public void stop() {
        this.total += (System.currentTimeMillis() - this.lastStartTime);
        this.active = false;
    }

    public AccumulatedData(UUID uuid) {
        this.uuid = uuid;
        this.starts = 1;
        this.total = 0;
        this.firstLoginTimeStamp = 0;
        this.averageTime = 0;
        this.active = false;
    }

    public AccumulatedData(UUID uuid, long total, long starts, long firstLoginTimeStamp) {
        this.uuid = uuid;
        this.total = total;
        this.starts = starts;
        this.firstLoginTimeStamp = firstLoginTimeStamp;
    }

    public UUID getUuid() {
        return uuid;
    }

    public long getTotal() {
        if (active)
            return total + (System.currentTimeMillis() - lastStartTime);
        return total;
    }

    public long getStarts() {
        return starts;
    }

    public long getFirstLoginTimeStamp() {
        return firstLoginTimeStamp;
    }

    public long getAverageTime() {
        return getTotal() / this.starts;
    }

    public boolean isActive() {
        return active;
    }

    @Override
    public Map<String, Object> serialize() {
        HashMap<String, Object> hashMap = new HashMap<>();
        hashMap.put("uuid", getUuid().toString());
        hashMap.put("total", getTotal());
        hashMap.put("punched_in_count", getStarts());
        hashMap.put("first_punch_in", getFirstLoginTimeStamp());
        return hashMap;
    }

    public static AccumulatedData deserialize(Map<String, Object> args) {
        AccumulatedData aData = new AccumulatedData(
                UUID.fromString((String)args.get("uuid")),
                ((Number) args.get("total")).longValue(),
                ((Number) args.get("punched_in_count")).longValue(),
                ((Number) args.get("first_punch_in")).longValue()
        );
        return aData;
    }

    public static Predicate<AccumulatedData> onlyActive() {
        return (accData) -> accData.isActive();
    }

    @Override
    public UUID getKey() {
        return getUuid();
    }

    @Override
    public AccumulatedData getValue() {
        return this;
    }
}