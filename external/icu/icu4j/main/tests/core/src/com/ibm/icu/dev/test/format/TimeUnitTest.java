/*
 *******************************************************************************
 * Copyright (C) 2008-2014, International Business Machines Corporation and    *
 * others. All Rights Reserved.                                                *
 *******************************************************************************
 */
package com.ibm.icu.dev.test.format;

import java.text.ParseException;
import java.text.ParsePosition;
import java.util.Locale;

import com.ibm.icu.dev.test.TestFmwk;
import com.ibm.icu.math.BigDecimal;
import com.ibm.icu.text.MeasureFormat;
import com.ibm.icu.text.NumberFormat;
import com.ibm.icu.text.TimeUnitFormat;
import com.ibm.icu.util.Measure;
import com.ibm.icu.util.MeasureUnit;
import com.ibm.icu.util.TimeUnit;
import com.ibm.icu.util.TimeUnitAmount;
import com.ibm.icu.util.ULocale;

/**
 * @author markdavis
 *
 */
public class TimeUnitTest extends TestFmwk {
    public static void main(String[] args) throws Exception{
        new TimeUnitTest().run(args);
    }
    
    public void Test10219FractionalPlurals() {
        TimeUnitFormat tuf = new TimeUnitFormat(ULocale.ENGLISH, TimeUnitFormat.FULL_NAME);
        String[] expected = {"1 minute", "1.5 minutes", "1.58 minutes"};
        for (int i = 2; i >= 0; i--) {
            NumberFormat nf = NumberFormat.getNumberInstance(ULocale.ENGLISH);
            nf.setRoundingMode(BigDecimal.ROUND_DOWN);
            nf.setMaximumFractionDigits(i);
            tuf.setNumberFormat(nf);
            assertEquals("Test10219", expected[i], tuf.format(new TimeUnitAmount(1.588, TimeUnit.MINUTE)));
        }   
    }
    
    public void Test10219FactionalPluralsParse() throws ParseException {
        TimeUnitFormat tuf = new TimeUnitFormat(ULocale.ENGLISH, TimeUnitFormat.FULL_NAME);
        ParsePosition ppos = new ParsePosition(0);
        String parseString = "1 minutes";
        tuf.parseObject(parseString, ppos);
        
        // Parsing should go all the way to the end of the string.
        // We want the longest match, and we don't care if the plural form of the unit
        // matches the plural form of the number.
        assertEquals("Test10219FractionalPluralParse", parseString.length(), ppos.getIndex());
    }

    public void TestBasic() {
        String[] locales = {"en", "sl", "fr", "zh", "ar", "ru", "zh_Hant"};
        for ( int locIndex = 0; locIndex < locales.length; ++locIndex ) {
            //System.out.println("locale: " + locales[locIndex]);
            TimeUnitFormat[] formats = new TimeUnitFormat[] {
                new TimeUnitFormat(new ULocale(locales[locIndex]), TimeUnitFormat.FULL_NAME),
                new TimeUnitFormat(new ULocale(locales[locIndex]), TimeUnitFormat.ABBREVIATED_NAME),
                
            };
            for (int style = TimeUnitFormat.FULL_NAME;
                 style <= TimeUnitFormat.ABBREVIATED_NAME;
                 ++style) {
                final TimeUnit[] values = TimeUnit.values();
                for (int j = 0; j < values.length; ++j) {
                    final TimeUnit timeUnit = values[j];
                    double[] tests = {0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 5, 10, 100, 101.35};
                    for (int i = 0; i < tests.length; ++i) {
                        TimeUnitAmount source = new TimeUnitAmount(tests[i], timeUnit);
                        String formatted = formats[style].format(source);
                        //System.out.println(formatted);
                        logln(tests[i] + " => " + formatted);
                        try {
                            // Style should not matter when parsing.
                            for (int parseStyle = TimeUnitFormat.FULL_NAME; parseStyle <= TimeUnitFormat.ABBREVIATED_NAME; parseStyle++) {
                                TimeUnitAmount result = (TimeUnitAmount) formats[parseStyle].parseObject(formatted);
                                if (result == null || !source.equals(result)) {
                                    errln("No round trip: " + source + " => " + formatted + " => " + result);
                                }
                            }
                        } catch (ParseException e) {
                            errln(e.getMessage());
                        }
                    }
                }
            }
        }
    }

    public void TestAPI() {
        TimeUnitFormat format = new TimeUnitFormat();
        format.setLocale(new ULocale("pt_BR"));
        formatParsing(format);
        format = new TimeUnitFormat(new ULocale("de"));
        formatParsing(format);
        format = new TimeUnitFormat(new ULocale("ja"));
        format.setNumberFormat(NumberFormat.getNumberInstance(new ULocale("en")));
        formatParsing(format);

        format = new TimeUnitFormat();
        ULocale es = new ULocale("es");
        format.setNumberFormat(NumberFormat.getNumberInstance(es));
        format.setLocale(es);
        formatParsing(format);
        
        format.setLocale(new Locale("pt_BR"));
        formatParsing(format);
        format = new TimeUnitFormat(new Locale("de"));
        formatParsing(format);
        format = new TimeUnitFormat(new Locale("ja"));
        format.setNumberFormat(NumberFormat.getNumberInstance(new Locale("en")));
        formatParsing(format);
    }
    
    public void TestClone() {
        TimeUnitFormat tuf = new TimeUnitFormat(ULocale.ENGLISH, TimeUnitFormat.ABBREVIATED_NAME);
        NumberFormat nf = NumberFormat.getInstance();
        tuf.setNumberFormat(nf);
        TimeUnitFormat tufClone = (TimeUnitFormat) tuf.clone();
        tuf.setLocale(Locale.GERMAN);
        assertEquals("", "1 hr", tufClone.format(new TimeUnitAmount(1, TimeUnit.HOUR)));
    }
    
    public void TestEqHashCode() {
        TimeUnitFormat tf = new TimeUnitFormat(ULocale.ENGLISH, TimeUnitFormat.FULL_NAME);
        MeasureFormat tfeq = new TimeUnitFormat(ULocale.ENGLISH, TimeUnitFormat.FULL_NAME);
        
        MeasureFormat tfne = new TimeUnitFormat(ULocale.ENGLISH, TimeUnitFormat.ABBREVIATED_NAME);
        MeasureFormat tfne2 = new TimeUnitFormat(ULocale.GERMAN, TimeUnitFormat.FULL_NAME);
        verifyEqualsHashCode(tf, tfeq, tfne);
        verifyEqualsHashCode(tf, tfeq, tfne2);
    }
    
    public void TestGetLocale() {
        TimeUnitFormat tf = new TimeUnitFormat(ULocale.GERMAN);
        assertEquals("", ULocale.GERMAN, tf.getLocale(ULocale.VALID_LOCALE));
    }

    /*
     * @bug 7902
     * This tests that requests for short unit names correctly fall back 
     * to long unit names for a locale where the locale data does not 
     * provide short unit names. As of CLDR 1.9, Greek is one such language.
     */
    public void TestGreek() {
        String[] locales = {"el_GR", "el"};
        final TimeUnit[] units = new TimeUnit[]{
                TimeUnit.SECOND,
                TimeUnit.MINUTE,
                TimeUnit.HOUR,
                TimeUnit.DAY,
                TimeUnit.WEEK,
                TimeUnit.MONTH,
                TimeUnit.YEAR};
        int[] styles = new int[] {TimeUnitFormat.FULL_NAME, TimeUnitFormat.ABBREVIATED_NAME};
        int[] numbers = new int[] {1, 7};

        String[] expected = {
                // "el_GR" 1 wide
                "1 ????????????????????????",
                "1 ??????????",
                "1 ??????",
                "1 ??????????",
                "1 ????????????????",
                "1 ??????????",
                "1 ????????",
                // "el_GR" 1 short
                "1 ????????.",
                "1 ??????.",
                "1 ??????",
                "1 ??????????",
                "1 ??????.",
                "1 ??????.",
                "1 ????.",	        // year (one)
                // "el_GR" 7 wide
                "7 ????????????????????????",
                "7 ??????????",
                "7 ????????",
                "7 ????????????",
                "7 ??????????????????",
                "7 ??????????",
                "7 ??????",
                // "el_GR" 7 short
                "7 ????????.",
                "7 ??????.",
                "7 ????.",		    // hour (other)
                "7 ????????????",
                "7 ??????.",
                "7 ??????.",
                "7 ????.",            // year (other)
                // "el" 1 wide
                "1 ????????????????????????",
                "1 ??????????",
                "1 ??????",
                "1 ??????????",
                "1 ????????????????",
                "1 ??????????",
                "1 ????????",
                // "el" 1 short
                "1 ????????.",
                "1 ??????.",
                "1 ??????",
                "1 ??????????",
                "1 ??????.",
                "1 ??????.",
                "1 ????.",	        // year (one)
                // "el" 7 wide
                "7 ????????????????????????",
                "7 ??????????",
                "7 ????????",
                "7 ????????????",
                "7 ??????????????????",
                "7 ??????????",
                "7 ??????",
                // "el" 7 short
                "7 ????????.",
                "7 ??????.",
                "7 ????.",		    // hour (other)
                "7 ????????????",
                "7 ??????.",
                "7 ??????.",
                "7 ????."};           // year (other

        int counter = 0;
        TimeUnitFormat timeUnitFormat;
        TimeUnitAmount timeUnitAmount;
        String formatted;

        for ( int locIndex = 0; locIndex < locales.length; ++locIndex ) {
            for( int numIndex = 0; numIndex < numbers.length; ++numIndex ) {
                for ( int styleIndex = 0; styleIndex < styles.length; ++styleIndex ) {
                    for ( int unitIndex = 0; unitIndex < units.length; ++unitIndex ) {

                        timeUnitAmount = new TimeUnitAmount(numbers[numIndex], units[unitIndex]);
                        timeUnitFormat = new TimeUnitFormat(new ULocale(locales[locIndex]), styles[styleIndex]);
                        formatted = timeUnitFormat.format(timeUnitAmount);

                        assertEquals(
                                "locale: " + locales[locIndex]
                                        + ", style: " + styles[styleIndex] 
                                                + ", units: " + units[unitIndex]
                                                        + ", value: " + numbers[numIndex], 
                                                expected[counter], formatted);
                        ++counter;
                    }
                }
            }
        }
    }

    /**
     * @bug9042 
     * Performs tests for Greek.
     * This tests that if the plural count listed in time unit format does not 
     * match those in the plural rules for the locale, those plural count in 
     * time unit format will be ingored and subsequently, fall back will kick in 
     * which is tested above. 
     * Without data sanitization, setNumberFormat() would crash. 
     * As of CLDR shiped in ICU4.8, Greek is one such language. 
     */ 
    public void TestGreekWithSanitization() {
        ULocale loc = new ULocale("el");
        NumberFormat numfmt = NumberFormat.getInstance(loc);
        TimeUnitFormat tuf = new TimeUnitFormat(loc);
        tuf.parseObject("", new ParsePosition(0));
        tuf.setNumberFormat(numfmt);        
    }


    private void formatParsing(TimeUnitFormat format) {
        final TimeUnit[] values = TimeUnit.values();
        for (int j = 0; j < values.length; ++j) {
            final TimeUnit timeUnit = values[j];
            double[] tests = {0, 0.5, 1, 2, 3, 5};
            for (int i = 0; i < tests.length; ++i) {
                TimeUnitAmount source = new TimeUnitAmount(tests[i], timeUnit);
                String formatted = format.format(source);
                //System.out.println(formatted);
                logln(tests[i] + " => " + formatted);
                try {
                    TimeUnitAmount result = (TimeUnitAmount) format.parseObject(formatted);
                    if (result == null || !source.equals(result)) {
                        errln("No round trip: " + source + " => " + formatted + " => " + result);
                    }
                } catch (ParseException e) {
                    errln(e.getMessage());
                }
            }
        }
    }
    
    /*
     * Tests the method public TimeUnitFormat(ULocale locale, int style), public TimeUnitFormat(Locale locale, int style)
     */
    @SuppressWarnings("unused")
    public void TestTimeUnitFormat() {
        // Tests when "if (style < FULL_NAME || style >= TOTAL_STYLES)" is true
        // TOTAL_STYLES is 2
        int[] cases = { TimeUnitFormat.FULL_NAME - 1, TimeUnitFormat.FULL_NAME - 2, 3 };
        for (int i = 0; i < cases.length; i++) {
            try {
                TimeUnitFormat tuf = new TimeUnitFormat(new ULocale("en_US"), cases[i]);
                errln("TimeUnitFormat(ULocale,int) was suppose to return an " + "exception for a style value of "
                        + cases[i] + "passed into the constructor.");
            } catch (Exception e) {
            }
        }
        for (int i = 0; i < cases.length; i++) {
            try {
                TimeUnitFormat tuf = new TimeUnitFormat(new Locale("en_US"), cases[i]);
                errln("TimeUnitFormat(ULocale,int) was suppose to return an " + "exception for a style value of "
                        + cases[i] + "passed into the constructor.");
            } catch (Exception e) {
            }
        }
    }
    
    /*
     * Tests the method public TimeUnitFormat setLocale(ULocale locale) public TimeUnitFormat setLocale(Locale locale)
     */
    public void TestSetLocale() {
        // Tests when "if ( locale != this.locale )" is false
        TimeUnitFormat tuf = new TimeUnitFormat(new ULocale("en_US"));
        if (!tuf.setLocale(new ULocale("en_US")).equals(tuf) && !tuf.setLocale(new Locale("en_US")).equals(tuf)) {
            errln("TimeUnitFormat.setLocale(ULocale) was suppose to "
                    + "return the same TimeUnitFormat object if the same " + "ULocale is entered as a parameter.");
        }
    }

    /*
     * Tests the method public TimeUnitFormat setNumberFormat(NumberFormat format)
     */
    public void TestSetNumberFormat() {
        TimeUnitFormat tuf = new TimeUnitFormat();

        // Tests when "if (format == this.format)" is false
        // Tests when "if ( format == null )" is false
        tuf.setNumberFormat(NumberFormat.getInstance());

        // Tests when "if (format == this.format)" is true
        if (!tuf.setNumberFormat(NumberFormat.getInstance()).equals(tuf)) {
            errln("TimeUnitFormat.setNumberFormat(NumberFormat) was suppose to "
                    + "return the same object when the same NumberFormat is passed.");
        }

        // Tests when "if ( format == null )" is true
        // Tests when "if ( locale == null )" is true
        if (!tuf.setNumberFormat(null).equals(tuf)) {
            errln("TimeUnitFormat.setNumberFormat(NumberFormat) was suppose to "
                    + "return the same object when null is passed.");
        }

        TimeUnitFormat tuf1 = new TimeUnitFormat(new ULocale("en_US"));

        // Tests when "if ( locale == null )" is false
        tuf1.setNumberFormat(NumberFormat.getInstance());
        tuf1.setNumberFormat(null);
    }
    
    /*
     * Tests the method public StringBuffer format(Object obj, ...
     */
    public void TestFormat() {
        TimeUnitFormat tuf = new TimeUnitFormat();
        try {
            tuf.format(new Integer("1"), null, null);
            errln("TimeUnitFormat.format(Object,StringBuffer,FieldPosition) "
                    + "was suppose to return an exception because the Object "
                    + "parameter was not of type TimeUnitAmount.");
        } catch (Exception e) {
        }
    }
    
    /* Tests the method private void setup() from
     * public Object parseObject(String source, ParsePosition pos)
     * 
     */
    public void TestSetup(){
        TimeUnitFormat tuf = new TimeUnitFormat();
        tuf.parseObject("", new ParsePosition(0));
        
        TimeUnitFormat tuf1 = new TimeUnitFormat();
        tuf1.setNumberFormat(NumberFormat.getInstance());
        tuf1.parseObject("", new ParsePosition(0));
    }
    
    public void TestStandInForMeasureFormat() {
        TimeUnitFormat tuf = new TimeUnitFormat(ULocale.FRENCH, TimeUnitFormat.ABBREVIATED_NAME);
        Measure measure = new Measure(23, MeasureUnit.CELSIUS);
        assertEquals("23 ??C", "23 ??C", tuf.format(measure));
        tuf = new TimeUnitFormat(ULocale.FRENCH, TimeUnitFormat.FULL_NAME);
        assertEquals(
                "70 pied et 5,3 pouces",
                "70 pieds et 5,3 pouces",
                tuf.formatMeasures(
                        new Measure(70, MeasureUnit.FOOT),
                        new Measure(5.3, MeasureUnit.INCH)));
        assertEquals("getLocale", ULocale.FRENCH, tuf.getLocale());
        assertEquals("getNumberFormat", ULocale.FRENCH, tuf.getNumberFormat().getLocale(ULocale.VALID_LOCALE));
        assertEquals("getWidth", MeasureFormat.FormatWidth.WIDE, tuf.getWidth());
    }
    
    private void verifyEqualsHashCode(Object o, Object eq, Object ne) {
        assertEquals("verifyEqualsHashCodeSame", o, o);
        assertEquals("verifyEqualsHashCodeEq", o, eq);
        assertNotEquals("verifyEqualsHashCodeNe", o, ne);
        assertNotEquals("verifyEqualsHashCodeEqTrans", eq, ne);
        assertEquals("verifyEqualsHashCodeHashEq", o.hashCode(), eq.hashCode());
        
        // May be a flaky test, but generally should be true.
        // May need to comment this out later.
        assertNotEquals("verifyEqualsHashCodeHashNe", o.hashCode(), ne.hashCode());
    }
}
