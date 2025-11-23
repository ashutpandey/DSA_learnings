public class DynamicArray {
    private int[] data;
    private int size;     
    private int capacity; 

    public DynamicArray(int initialCapacity) {
        if (initialCapacity <= 0) {
             throw new IllegalArgumentException("Initial capacity must be positive.");
        }
        this.capacity = initialCapacity;
        this.data = new int[initialCapacity];
        this.size = 0;
    }

    private void resize() {
        int newCapacity = capacity * 2;
        int[] newData = new int[newCapacity];
        for (int i = 0; i < size; i++) {
            newData[i] = data[i];
        }
        data = newData;
        capacity = newCapacity;
        System.out.println("Capacity doubled to " + capacity);
    }

    public void add(int ele, int pos) {
        if (size == capacity) {
            resize();
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

        del(pos);
    }

    public void print() {
        if (size == 0) {
            System.out.println("Array: [] (Empty), Capacity: " + capacity);
            return;
        }
        System.out.print("Array: [");
        for (int i = 0; i < size; i++) {
            System.out.print(data[i] + (i < size - 1 ? ", " : ""));
        }
        System.out.println("], Size: " + size + ", Capacity: " + capacity);
    }
}