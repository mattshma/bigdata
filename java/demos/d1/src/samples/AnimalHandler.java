package samples;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;

/**
 * Created by maming on 16/6/23.
 */
public class AnimalHandler implements InvocationHandler {

    private Object animal;

    public AnimalHandler(Object obj) {
        this.animal = obj;
    }

    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        // do something
        Object result = method.invoke(this.animal, args);
        //do other thing
        return result;
    }
}
