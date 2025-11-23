public class Main {
    public static void main(String[] args) {
        System.out.println("=== DynamicArray demo ===");
        DynamicArray da = new DynamicArray(2);
        da.add(10, 0);
        da.add(20, 1);
        da.add(15, 1);
        da.print();
        da.deleteByElement(20);
        da.print();
        da.del(0);
        da.print();

        System.out.println("\n=== StaticArray demo ===");
        StaticArray sa = new StaticArray(5);
        sa.add(1, 0);
        sa.add(2, 1);
        sa.add(3, 2);
        sa.print();
        sa.del(1);
        sa.print();
        sa.deleteByElement(3);
        sa.print();

        System.out.println("\n=== GenericArrayList demo ===");
        GenericArrayList<String> gal = new GenericArrayList<>();
        gal.add("one", 0);
        gal.add("two", 1);
        gal.add("three", 2);
        gal.print();

        System.out.println("Iterate with for-each:");
        for (String s : gal) {
            System.out.println("  " + s);
        }

        System.out.println("Iterate and remove 'two' using iterator:");
        java.util.Iterator<String> it = gal.iterator();
        while (it.hasNext()) {
            String s = it.next();
            if ("two".equals(s)) {
                it.remove();
                System.out.println("  Removed via iterator: " + s);
            }
        }
        gal.print();
    }
}
