/**
 * \file lnreg.cpp
 *
 * \date 3 Oct 2016
 * \author adamfowler
 */

#include <MarkLogic.h>
#include <cmath>
#include <string>
#include <map>
#include <functional>
#include <iostream>
#include <istream>

#ifdef _MSC_VER
#define PLUGIN_DLL __declspec(dllexport)
#else // !_MSC_VER
#define PLUGIN_DLL
#endif

using namespace marklogic;


/**
 * \brief This UDF calculates the logarithmic regression (ln reg) between two fields over a search results data set (two tuples)
 */
class LogRegUDF : public AggregateUDF {
public:

  AggregateUDF* clone() const {
    return (new LogRegUDF(*this));  // calls copy constructor
  }

  void start(Sequence& args, Reporter& reporter) {
    sumx = 0.0;sumy = 0.0;sumxx=0.0;sumxy=0.0;count = 0;
    try {
      for (; !args.done(); args.next()) {
        String argValue;
        args.value(argValue);
        std::string arg = std::string(argValue);

      } // end for
    } catch (std::exception& ex) {
      reporter.error(("Exception in start(): " + std::string(ex.what())).c_str());
    }
  }



  /**
   * \brief Get the values we need for the aggregate and cache them
   *
   * Assume the first column (index 0) is the group by field (with LOW cardinality)
   */
  void map(TupleIterator& values, Reporter& reporter) {
    try {
      for (; !values.done(); values.next()) {
          double x,y;
          uint64_t freq = values.frequency();
          values.value(0,x);
          values.value(1,y);
          sumx += freq * x;
          sumy += freq * y;
          sumxx += freq * x * x;
          sumxy += freq * x * y;
          count += freq;
      }

    } catch (std::exception& ex) {
      reporter.error(("Exception in map(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Reduce down the values from another aggregate UDF instance, and copy in to this aggregate instance
   */
  void reduce(const AggregateUDF* otherAgg, Reporter& reporter) {
    try {
      // loop through other's values and add to our equivalent value (if exists)
      // if doesn't exist in our values, add to our values
      const LogRegUDF* other = (const LogRegUDF*)otherAgg;
      sumx += other->sumx;
      sumy += other->sumy;
      sumxx += other->sumxx;
      sumxy += other->sumxy;
      count += other->count;
    } catch (std::exception& ex) {
      reporter.error(("Exception in reduce(): " + std::string(ex.what())).c_str());
    }
  } // end reduce



  /**
   * \brief Encode to XDQP stream
   */
  void encode(Encoder& e, Reporter& reporter) {
    try {
      e.encode(sumx);
      e.encode(sumy);
      e.encode(sumxx);
      e.encode(sumxy);
      e.encode(count);
    } catch (std::exception& ex) {
      reporter.error(("Exception in encode(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Decode from XDQP stream
   */
  void decode(Decoder& d, Reporter& reporter) {
    try {
      d.decode(sumx);
      d.decode(sumy);
      d.decode(sumxx);
      d.decode(sumxy);
      d.decode(count);
    } catch (std::exception& ex) {
      reporter.error(("Exception in decode(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Return the final result from the remaining aggregate UDF instance
   */
  void finish(OutputSequence& os, Reporter& reporter) {
    try {
      // calculate A, B, string
      double B = (count * sumxy - sumx * sumy) / (count * sumxx - sumx * sumx);
      double A = (sumy - B * sumx) / count;
      //std::ostringstream oss;
      //oss << "log[odds]  = " << (round(A*100) / 100) << " + " << (round(B*100) / 100) << " ln(x)";
      // write output
      os.startMap();
      os.writeMapKey("A");
      os.writeValue(A);
      os.writeMapKey("B");
      os.writeValue(B);
      //os.writeMapKey("string");
      //os.writeValue(oss.str());
      os.writeMapKey("count");
      os.writeValue(count);
      os.endMap();
    } catch (std::exception& ex) {
      reporter.error(("Exception in finish(): " + std::string(ex.what())).c_str());
    }
  }

  /**
   * \brief Clear up resources from this aggregate UDF
   */
  void close() {
    // NOT SAFE TO DELETE ANYTHING - called multiple times
  }

private:
  double sumx,sumy,sumxx,sumxy;
  long count;
};

extern "C" PLUGIN_DLL void marklogicPlugin(Registry& r) {
  r.version(1);
  r.registerAggregate<LogRegUDF>("logreg");
}




