/**
 * Builds the active dimension set from Health_Dimension__mdt. Adding a
 * dimension is one Apex class plus one metadata record; re-weighting is a
 * metadata edit with no deployment. A record pointing at a class that does
 * not exist or does not implement IHealthDimension is logged and skipped —
 * bad configuration must degrade the score, not kill the nightly batch.
 */
public inherited sharing class HealthDimensionFactory {
    public List<WeightedDimension> buildActiveDimensions() {
        List<WeightedDimension> dimensions = new List<WeightedDimension>();
        for (Health_Dimension__mdt config : Health_Dimension__mdt.getAll().values()) {
            if (!config.Active__c) {
                continue;
            }
            Type calculatorType = Type.forName(config.Calculator_Class__c);
            Object instance = calculatorType == null ? null : calculatorType.newInstance();
            if (instance instanceof IHealthDimension) {
                dimensions.add(
                    new WeightedDimension(config.DeveloperName, (IHealthDimension) instance, config.Weight__c)
                );
            } else {
                Logger.warn(
                    'HealthDimensionFactory',
                    'Skipping dimension ' +
                        config.DeveloperName +
                        ': class ' +
                        config.Calculator_Class__c +
                        ' is missing or does not implement IHealthDimension',
                    config.DeveloperName
                );
            }
        }
        return dimensions;
    }

    public class WeightedDimension {
        public final String developerName;
        public final IHealthDimension calculator;
        public final Decimal weight;

        public WeightedDimension(String developerName, IHealthDimension calculator, Decimal weight) {
            this.developerName = developerName;
            this.calculator = calculator;
            this.weight = weight;
        }
    }
}
