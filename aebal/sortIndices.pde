import java.util.*;

int[] getSortIndices(float[] vals) {
    final Float[] numbers = new Float[vals.length];
    Integer[] indicies = new Integer[vals.length];
    
    for(int i = 0; i < indicies.length; i++) {
        indicies[i] = i;
        numbers[i] = vals[i];
    }
    
    Arrays.sort(indicies, new Comparator<Integer>() {   
        public int compare(Integer a, Integer b){
            return sign(numbers[a] - numbers[b]);
        }
    });
    
    int[] finalIndicies = new int[indicies.length];
    for(int i = 0; i < indicies.length; i++) finalIndicies[i] = indicies[i];
    
    return finalIndicies;
}
float [] sortByIndicies(float[] vals, int[] indicies) {
    FloatList newVals = new FloatList();
    for(int i = 0; i < vals.length; i++) {
        newVals.append(vals[indicies[i]]);
    }
    return newVals.array();
}
String[] sortByIndicies(String[] vals, int[] indicies) {
    StringList newVals = new StringList();
    for(int i = 0; i < vals.length; i++) {
        newVals.append(vals[indicies[i]]);
    }
    return newVals.array();
}
int[] sortGetIndices(float[] vals) {
    int[] order = getSortIndices(vals);
    sortByIndicies(vals, order);
    return order;
}