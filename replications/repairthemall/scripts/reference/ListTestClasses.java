import fr.inria.astor.core.faultlocalization.entity.TestClassesFinder;
import fr.inria.astor.core.setup.FinderTestCases;

/** Print the test classes Astor's own finder sees on the given classpath. */
public class ListTestClasses {
    public static void main(String[] args) {
        for (String name : new TestClassesFinder().findIn(FinderTestCases.classpathFrom(args[0]), false))
            System.out.println(name);
    }
}
