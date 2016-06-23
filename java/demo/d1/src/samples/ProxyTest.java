package samples;

import java.lang.reflect.Proxy;

/**
 * Created by maming on 16/6/23.
 */
public class ProxyTest {

    public static void main(String[] args) {
        Dog dog = new Dog();
        ClassLoader loader = dog.getClass().getClassLoader();
        Class<?>[] it = dog.getClass().getInterfaces();
        AnimalHandler ah = new AnimalHandler(dog);
        Animal animal = (Animal) Proxy.newProxyInstance(loader, it, ah);
        animal.say();
    }
}
