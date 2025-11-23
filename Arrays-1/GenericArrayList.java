import java.util.ArrayList;
import java.util.Iterator;
import java.util.NoSuchElementException;

public class GenericArrayList<T> implements Iterable<T> {
    private ArrayList<T> data;

    public GenericArrayList() {
        this.data = new ArrayList<>();
    }

    public int size() {
        return data.size();
    }

    public void add(T ele, int pos) {
        if (pos < 0 || pos > data.size()) {
            System.out.println("Error: Invalid position. Position must be between 0 and " + data.size());
            return;
        }
        data.add(pos, ele);
        System.out.println("Added " + ele + " at position " + pos);
    }

    public void del(int pos) {
        if (data.isEmpty()) {
            System.out.println("Error: Array is empty. Cannot delete.");
            return;
        }
        if (pos < 0 || pos >= data.size()) {
            System.out.println("Error: Invalid position. Position must be between 0 and " + (data.size() - 1));
            return;
        }
        T deleted = data.remove(pos);
        System.out.println("Deleted " + deleted + " from position " + pos);
    }

    public void deleteByElement(T element) {
        int pos = data.indexOf(element);
        if (pos == -1) {
            System.out.println("Error: Element " + element + " not found in the array.");
            return;
        }
        del(pos);
    }

    public T get(int index) {
        return data.get(index);
    }

    public void print() {
        System.out.println("Array: " + data.toString() + ", Size: " + data.size());
    }

    @Override
    public Iterator<T> iterator() {
        return new GenericIterator();
    }

    private class GenericIterator implements Iterator<T> {
        private int cursor = 0;
        private boolean canRemove = false;

        @Override
        public boolean hasNext() {
            return cursor < data.size();
        }

        @Override
        public T next() {
            if (!hasNext()) {
                throw new NoSuchElementException();
            }
            T item = data.get(cursor);
            cursor++;
            canRemove = true;
            return item;
        }

        @Override
        public void remove() {
            if (!canRemove) {
                throw new IllegalStateException();
            }
            data.remove(--cursor);
            canRemove = false;
        }
    }
}
