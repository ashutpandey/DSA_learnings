public class StaticArray {
    private int[] data;
    private int size; 

    public StaticArray(int capacity) {
        if (capacity <= 0) {
            throw new IllegalArgumentException("Capacity must be positive.");
        }
        data = new int[capacity];
        size = 0;
    }

    public void add(int ele, int pos) {
        if (size == data.length) {
            System.out.println("Error: Array is full. Cannot add element.");
            return;
        }
        if (pos < 0 || pos > size) {
            System.out.println("Error: Invalid position. Position must be between 0 and " + size);
            return;
        }
        for (int i = size - 1; i >= pos; i--) {
            data[i + 1] = data[i];
        }
        data[pos] = ele;
        size++;
        System.out.println("Added " + ele + " at position " + pos);
    }

    // Method to delete an element at a given position (Signature: del(int))
    public void del(int pos) {
        if (size == 0) {
            System.out.println("Error: Array is empty. Cannot delete.");
            return;
        }
        if (pos < 0 || pos >= size) {
            System.out.println("Error: Invalid position. Position must be between 0 and " + (size - 1));
            return;
        }

        int deletedElement = data[pos];
        for (int i = pos; i < size - 1; i++) {
            data[i] = data[i + 1];
        }

        size--;
        data[size] = 0;
        System.out.println("Deleted " + deletedElement + " from position " + pos);
    }

    // Method to delete a specific element (Signature: deleteByElement(int))
    public void deleteByElement(int element) {
        int pos = -1;
        for (int i = 0; i < size; i++) {
            if (data[i] == element) {
                pos = i;
                break;
            }
        }

        if (pos == -1) {
            System.out.println("Error: Element " + element + " not found in the array.");
            return;
        }

        // Delegate to the position-based deletion method
        del(pos);
    }

    public void print() {
        if (size == 0) {
            System.out.println("Array: [] (Empty)");
            return;
        }
        System.out.print("Array: [");
        for (int i = 0; i < size; i++) {
            System.out.print(data[i] + (i < size - 1 ? ", " : ""));
        }
        System.out.println("]");
    }
}